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
from site_config import IS_ARM, IS_WINDOWS, IS_COVERAGE

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

    Args:
        job: TestJob instance
        deployment_type: The deployment type to use (may differ from job.options.deployment_type)
        prefix: Prefix for the test name (e.g., "sg_" or "cl_")
        suite_index: If provided, extract only this suite (for buckets:auto splitting)

    Returns:
        Dictionary in legacy format with keys: name, prefix, priority, parallelity,
        flags, params, args
    """
    # Determine if this is a cluster test
    is_cluster = deployment_type == DeploymentType.CLUSTER

    # Build flags list
    flags = []

    # Add deployment type flag (only if explicitly set)
    if deployment_type is not None:
        if deployment_type == DeploymentType.SINGLE:
            flags.append("single")
        elif deployment_type == DeploymentType.CLUSTER:
            flags.append("cluster")
        elif deployment_type == DeploymentType.MIXED:
            flags.append("mixed")

    # Add full/!full flag
    # When splitting by suite, use suite-level full if available
    full_value = None
    if suite_index is not None and job.suites[suite_index].options:
        full_value = job.suites[suite_index].options.full
    if full_value is None:
        full_value = job.options.full

    if full_value is True:
        flags.append("full")
    elif full_value is False:
        flags.append("!full")

    # Add coverage flag
    # When splitting by suite, use suite-level coverage if available
    coverage_value = None
    if suite_index is not None and job.suites[suite_index].options:
        coverage_value = job.suites[suite_index].options.coverage
    if coverage_value is None:
        coverage_value = job.options.coverage

    if coverage_value is True:
        flags.append("coverage")
    elif coverage_value is False:
        flags.append("!coverage")

    # Build params dict
    params = {}

    if job.options.suffix:
        params["suffix"] = job.options.suffix

    # When suite_index is provided (buckets:auto splitting), extract only that suite
    if suite_index is not None:
        suite = job.suites[suite_index]
        job_name = suite.name

        # Build args by combining job-level and suite-specific arguments
        # Start with job-level args
        args = (
            job.arguments.extra_args.copy()
            if job.arguments and job.arguments.extra_args
            else []
        )
        # Add suite-specific args
        if suite.arguments and suite.arguments.extra_args:
            args.extend(suite.arguments.extra_args)
    else:
        # Regular job - use job name and job-level arguments
        job_name = job.name

        # Build args list (use extra_args from TestArguments)
        args = (
            job.arguments.extra_args.copy()
            if job.arguments and job.arguments.extra_args
            else []
        )

        # For multi-suite jobs, add optionsJson
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
    # When splitting by suite, use suite-level priority if available
    if (
        suite_index is not None
        and job.suites[suite_index].options
        and job.suites[suite_index].options.priority is not None
    ):
        priority = job.suites[suite_index].options.priority
    elif job.options.priority is not None:
        priority = job.options.priority
    else:
        priority = 250

    # Determine parallelity (default: 4 for cluster, 1 for single)
    # When splitting by suite, use suite-level parallelity if available
    if (
        suite_index is not None
        and job.suites[suite_index].options
        and job.suites[suite_index].options.parallelity is not None
    ):
        parallelity = job.suites[suite_index].options.parallelity
    elif job.options.parallelity is not None:
        parallelity = job.options.parallelity
    else:
        parallelity = 4 if is_cluster else 1

    return {
        "name": job_name,
        "prefix": prefix,
        "priority": priority,
        "parallelity": parallelity,
        "flags": flags,
        "params": params,
        "args": args,
    }


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
            deployment_type = job.options.deployment_type
            # For buckets:auto jobs with multiple suites, split into separate jobs
            if job.options.buckets == "auto" and len(job.suites) > 1:
                for suite_idx in range(len(job.suites)):
                    legacy_test = convert_job_to_legacy_format(
                        job, deployment_type, suite_index=suite_idx
                    )
                    legacy_tests.append(legacy_test)
            else:
                legacy_test = convert_job_to_legacy_format(job, deployment_type)
                legacy_tests.append(legacy_test)
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
            # Single mode based on --cluster flag - use job's actual deployment type for flags
            job_deployment = job.options.deployment_type
            if args.cluster:
                filter_mode = DeploymentType.CLUSTER
            else:
                filter_mode = DeploymentType.SINGLE
            deployment_types_to_test.append((job_deployment, filter_mode, ""))

        # Process each deployment type
        for item in deployment_types_to_test:
            if len(item) == 2:
                # single_cluster mode: (deployment_type_for_flags, prefix)
                deployment_type, prefix = item
                filter_mode = None
            else:
                # normal mode: (deployment_type_for_flags, filter_mode, prefix)
                deployment_type, filter_mode, prefix = item
            # Create a filter context
            is_full = args.full
            is_enterprise = args.enterprise

            # Check if job should be included based on deployment type compatibility
            # Only apply filtering in normal mode (not single_cluster mode)
            if filter_mode is not None:
                job_deployment = job.options.deployment_type

                # Jobs without explicit deployment_type can run in any mode
                if job_deployment is not None:
                    # Skip if job explicitly requires single and we're testing cluster
                    if (
                        job_deployment == DeploymentType.SINGLE
                        and filter_mode == DeploymentType.CLUSTER
                    ):
                        continue

                    # Skip if job explicitly requires cluster and we're testing single
                    if (
                        job_deployment == DeploymentType.CLUSTER
                        and filter_mode == DeploymentType.SINGLE
                    ):
                        continue
            else:
                # In single_cluster mode, use deployment_type for filtering
                job_deployment = job.options.deployment_type

                # Jobs without explicit deployment_type can run in any mode
                if job_deployment is not None:
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

            # For buckets:auto jobs with multiple suites, split into separate jobs
            if job.options.buckets == "auto" and len(job.suites) > 1:
                for suite_idx in range(len(job.suites)):
                    legacy_test = convert_job_to_legacy_format(
                        job, deployment_type, prefix, suite_index=suite_idx
                    )
                    # In cluster filtering mode, add the cluster flag if not present
                    # (old controller only adds flag for cluster mode, not single mode)
                    if (
                        filter_mode == DeploymentType.CLUSTER
                        and "cluster" not in legacy_test["flags"]
                    ):
                        legacy_test["flags"].append("cluster")
                    legacy_tests.append(legacy_test)
            else:
                # Convert to legacy format
                legacy_test = convert_job_to_legacy_format(job, deployment_type, prefix)
                # In cluster filtering mode, add the cluster flag if not present
                # (old controller only adds flag for cluster mode, not single mode)
                if (
                    filter_mode == DeploymentType.CLUSTER
                    and "cluster" not in legacy_test["flags"]
                ):
                    legacy_test["flags"].append("cluster")
                legacy_tests.append(legacy_test)

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
