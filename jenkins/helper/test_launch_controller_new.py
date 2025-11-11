#!/bin/env python3
"""
Test launch controller for Jenkins/Oskar.

Reads test definitions from YAML files and either:
- Validates and dumps test information (dump mode)
- Launches tests (launch mode)

This implementation reuses the clean data structures from src/config_lib.py
and does NOT support driver tests (repository config is ignored).
"""
import argparse
import sys
from pathlib import Path
from typing import List

from src.config_lib import TestDefinitionFile, TestJob, DeploymentType
from src.filters import should_include_job
from site_config import IS_ARM, IS_WINDOWS, IS_MAC, IS_COVERAGE

from dump_handler import generate_dump_output
from launch_handler import launch

# Check python 3
if sys.version_info[0] != 3:
    print("found unsupported python version ", sys.version_info)
    sys.exit(1)


def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Test launch controller for Jenkins/Oskar"
    )
    parser.add_argument(
        "definitions", help="YAML file containing test definitions", type=str
    )
    parser.add_argument(
        "-f",
        "--format",
        type=str,
        choices=["dump", "launch"],
        default="launch",
        help="Output format: 'dump' for test info or 'launch' to run tests",
    )
    parser.add_argument(
        "--validate-only",
        help="Validate test definition file and exit",
        action="store_true",
    )
    parser.add_argument(
        "--cluster",
        help="Run only cluster tests (default: single server)",
        action="store_true",
    )
    parser.add_argument(
        "--single_cluster",
        help="Run both single and cluster tests",
        action="store_true",
    )
    parser.add_argument(
        "--enterprise", help="Include enterprise tests", action="store_true"
    )
    parser.add_argument(
        "--full", help="Run full test set (default: PR tests only)", action="store_true"
    )
    parser.add_argument("--gtest", help="Only run gtest suites", action="store_true")
    parser.add_argument(
        "--all", help="Run all tests, ignore other filters", action="store_true"
    )
    parser.add_argument(
        "--no-report",
        help="Don't create test reports and crash tarballs",
        action="store_true",
    )

    return parser.parse_args()


def convert_job_to_legacy_format(
    job: TestJob,
    deployment_type: DeploymentType,
    prefix: str = "",
    suite_index: int = None,
) -> dict:
    """
    Convert a TestJob from the clean data model to the legacy dict format
    expected by dump_handler and launch_handler.

    For Jenkins, multi-suite jobs are split into separate jobs (one per suite).

    Args:
        job: TestJob instance
        deployment_type: The deployment type to use (may differ from job.options.deployment_type)
        prefix: Prefix for the test name (e.g., "sg_" or "cl_")
        suite_index: If provided, only convert the suite at this index (for splitting multi-suite jobs)

    Returns:
        Dictionary in legacy format with keys: name, prefix, priority, parallelity,
        flags, params, args
    """
    # Determine if this is a cluster test
    is_cluster = deployment_type == DeploymentType.CLUSTER

    # Build flags list
    flags = []

    # Add deployment type flag
    if deployment_type == DeploymentType.SINGLE:
        flags.append("single")
    elif deployment_type == DeploymentType.CLUSTER:
        flags.append("cluster")
    elif deployment_type == DeploymentType.MIXED:
        flags.append("mixed")

    # Add full/!full flag
    if job.options.full is True:
        flags.append("full")
    elif job.options.full is False:
        flags.append("!full")

    # Add coverage flag
    if job.options.coverage is True:
        flags.append("coverage")
    elif job.options.coverage is False:
        flags.append("!coverage")

    # Build params dict
    params = {}

    if job.options.suffix:
        params["suffix"] = job.options.suffix

    # Determine which suite(s) to include
    # If suite_index is provided, we're splitting a multi-suite job
    if suite_index is not None:
        suites_to_process = [job.suites[suite_index]]
        # Use suite-specific args if available
        suite_args = (
            suites_to_process[0].arguments.extra_args
            if suites_to_process[0].arguments
            else []
        )
        args = (
            list(job.arguments.extra_args) + suite_args if job.arguments else suite_args
        )
    else:
        suites_to_process = job.suites
        # Build args list (use extra_args from TestArguments)
        args = (
            job.arguments.extra_args.copy()
            if job.arguments and job.arguments.extra_args
            else []
        )

        # For multi-suite jobs (when not splitting), add optionsJson
        if len(job.suites) > 1:
            import json

            options_json = []
            for suite in job.suites:
                # Convert suite arguments to dict format for optionsJson
                suite_args = {}
                if suite.arguments and suite.arguments.extra_args:
                    # Parse extra_args back into dict format
                    i = 0
                    while i < len(suite.arguments.extra_args):
                        arg = suite.arguments.extra_args[i]
                        if arg.startswith("--"):
                            key = arg[2:]  # Remove -- prefix

                            # Get the value
                            value = None
                            if i + 1 < len(suite.arguments.extra_args):
                                next_arg = suite.arguments.extra_args[i + 1]
                                if not next_arg.startswith("--"):
                                    # Convert string booleans back to bool
                                    if next_arg == "true":
                                        value = True
                                    elif next_arg == "false":
                                        value = False
                                    else:
                                        value = next_arg
                                    i += 2
                                else:
                                    # Boolean flag without explicit value
                                    value = True
                                    i += 1
                            else:
                                # Boolean flag at end
                                value = True
                                i += 1

                            # Handle colon-separated keys (nest them)
                            if ":" in key:
                                keyparts = key.split(":", 1)
                                parent_key, child_key = keyparts[0], keyparts[1]
                                if parent_key not in suite_args:
                                    suite_args[parent_key] = {}
                                suite_args[parent_key][child_key] = value
                            else:
                                suite_args[key] = value
                        else:
                            i += 1

                options_json.append(suite_args)

            # Add optionsJson as a command-line argument
            args.extend(
                ["--optionsJson", json.dumps(options_json, separators=(",", ":"))]
            )

    # Determine priority (default 250)
    priority = job.options.priority if job.options.priority is not None else 250

    # Determine parallelity (default: 4 for cluster, 1 for single)
    if job.options.parallelity is not None:
        parallelity = job.options.parallelity
    else:
        parallelity = 4 if is_cluster else 1

    # Determine job name - use suite name if we're splitting
    if suite_index is not None:
        job_name = suites_to_process[0].name
    else:
        job_name = job.name

    return {
        "name": job_name,
        "prefix": prefix,
        "priority": priority,
        "parallelity": parallelity,
        "flags": flags,
        "params": params,
        "args": args,
    }


def _convert_and_split_job(
    job: TestJob, deployment_type: DeploymentType, prefix: str = ""
) -> List[dict]:
    """
    Convert a job to legacy format, splitting multi-suite jobs if needed.

    For Jenkins, multi-suite jobs are split into separate jobs (one per suite).

    Args:
        job: TestJob instance
        deployment_type: Deployment type to use
        prefix: Prefix for test name (e.g., "sg_" or "cl_")

    Returns:
        List of legacy format dictionaries (one per suite for multi-suite jobs)
    """
    if len(job.suites) > 1:
        # Split multi-suite job into separate jobs
        return [
            convert_job_to_legacy_format(
                job, deployment_type, prefix, suite_index=suite_idx
            )
            for suite_idx in range(len(job.suites))
        ]
    else:
        # Single-suite job
        return [convert_job_to_legacy_format(job, deployment_type, prefix)]


def filter_and_convert_jobs(test_def: TestDefinitionFile, args) -> List[dict]:
    """
    Filter jobs based on command-line arguments and convert to legacy format.

    Args:
        test_def: Parsed test definition file
        args: Command-line arguments

    Returns:
        List of test dictionaries in legacy format
    """
    legacy_tests = []

    # Determine platform flags
    platform_flags = set()
    if IS_WINDOWS:
        platform_flags.add("exclude_windows")
    if IS_MAC:
        platform_flags.add("exclude_mac")
    if IS_ARM:
        platform_flags.add("exclude_arm")
    if IS_COVERAGE:
        platform_flags.add("exclude_coverage")

    for job_name, job in test_def.jobs.items():
        # Skip driver tests (jobs with repository config)
        if job.repository is not None:
            continue

        # Apply gtest filter
        if args.gtest and not job_name.startswith("gtest"):
            continue

        # If --all flag is set, skip filtering
        if args.all:
            deployment_type = job.options.deployment_type or DeploymentType.SINGLE
            legacy_tests.extend(_convert_and_split_job(job, deployment_type))
            continue

        # Determine which deployment types to test
        deployment_types_to_test = []

        if args.single_cluster:
            # Test both single and cluster
            job_deployment = job.options.deployment_type or DeploymentType.SINGLE

            if job_deployment == DeploymentType.MIXED:
                # Mixed tests run in both modes
                deployment_types_to_test.append((DeploymentType.SINGLE, "sg_"))
                deployment_types_to_test.append((DeploymentType.CLUSTER, "cl_"))
            elif job_deployment == DeploymentType.CLUSTER:
                # Cluster-only tests only run in cluster mode
                deployment_types_to_test.append((DeploymentType.CLUSTER, "cl_"))
            else:
                # Single or unspecified - run in both modes
                deployment_types_to_test.append((DeploymentType.SINGLE, "sg_"))
                deployment_types_to_test.append((DeploymentType.CLUSTER, "cl_"))
        else:
            # Single mode based on --cluster flag
            if args.cluster:
                deployment_type = DeploymentType.CLUSTER
            else:
                deployment_type = DeploymentType.SINGLE
            deployment_types_to_test.append((deployment_type, ""))

        # Process each deployment type
        for deployment_type, prefix in deployment_types_to_test:
            # Create a filter context
            is_full = args.full
            is_enterprise = args.enterprise

            # Check if job should be included based on deployment type compatibility
            job_deployment = job.options.deployment_type or DeploymentType.SINGLE

            # Skip if job explicitly requires single and we're testing cluster
            if (
                job_deployment == DeploymentType.SINGLE
                and deployment_type == DeploymentType.CLUSTER
            ):
                continue

            # Skip if job explicitly requires cluster and we're testing single
            if (
                job_deployment == DeploymentType.CLUSTER
                and deployment_type == DeploymentType.SINGLE
            ):
                continue

            # Apply full/PR filter
            if job.options.full is True and not is_full:
                continue  # Skip full-only tests in PR mode
            if job.options.full is False and is_full:
                continue  # Skip PR-only tests in full mode

            # Note: Enterprise and platform exclusion filtering is NOT supported
            # in the YAML format. Those flags only existed in the old text-based format.
            # The old controller didn't have these in YAML either.

            # Convert and split multi-suite jobs if needed
            legacy_tests.extend(_convert_and_split_job(job, deployment_type, prefix))

    return legacy_tests


def main():
    """Main entry point."""
    try:
        args = parse_arguments()

        # Load test definitions using the clean data model
        test_def = TestDefinitionFile.from_yaml_file(args.definitions)

        if args.validate_only:
            print(f"Successfully validated {args.definitions}")
            return

        # Filter and convert jobs to legacy format
        tests = filter_and_convert_jobs(test_def, args)

        # Handle no-report flag
        if args.no_report:
            print("Disabling report generation")
            args.create_report = False
        else:
            args.create_report = True

        # Generate output using the legacy handlers
        if args.format == "dump":
            generate_dump_output(args, tests)
        elif args.format == "launch":
            launch(args, tests)
        else:
            raise ValueError(f"Unknown format: {args.format}")

    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
