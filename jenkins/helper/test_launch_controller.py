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
import json
import sys
from copy import deepcopy
from dataclasses import dataclass
from typing import List, Union, Dict, Any, Optional, Tuple

from src.config_lib import TestDefinitionFile, TestJob, DeploymentType
from src.filters import filter_suites, FilterCriteria, should_include_job

from dump_handler import generate_dump_output
from launch_handler import launch

# Check python 3
if sys.version_info[0] != 3:
    print("found unsupported python version ", sys.version_info)
    sys.exit(1)

# Constants
DEFAULT_PRIORITY = 250
DEFAULT_PARALLELITY_CLUSTER = 4
DEFAULT_PARALLELITY_SINGLE = 1
SPECIAL_ARG_MORE_ARGV = "moreArgv"
PREFIX_SINGLE = "sg_"
PREFIX_CLUSTER = "cl_"


@dataclass
class DeploymentConfig:
    """Configuration for how to test a specific deployment type."""

    deployment_type: DeploymentType
    deployment_requirement: Optional[DeploymentType]  # None when --single_cluster (no deployment filtering)
    prefix: str


def build_filter_criteria(args, config: Optional[DeploymentConfig] = None) -> FilterCriteria:
    """Build FilterCriteria from command-line args and optional deployment config.

    Args:
        args: Command-line arguments
        config: Optional deployment configuration (None for --single_cluster flag case)

    Returns:
        FilterCriteria object for filtering jobs
    """
    # Determine cluster/single flags based on config
    if config is None or config.deployment_requirement is None:
        # --single_cluster flag: no deployment requirement
        cluster = False
        single = False
    else:
        # Normal mode: filter based on deployment requirement
        cluster = (config.deployment_requirement == DeploymentType.CLUSTER)
        single = (config.deployment_requirement == DeploymentType.SINGLE)

    return FilterCriteria(
        cluster=cluster,
        single=single,
        full=args.full,
        gtest=args.gtest,
        all_tests=False,
    )


def dict_to_args_list(args_data: dict) -> List[str]:
    """Convert args dict to command-line list format."""
    result = []
    for key, value in args_data.items():
        if key == SPECIAL_ARG_MORE_ARGV:
            # Special case: moreArgv value is appended directly
            result.append(str(value))
        else:
            result.append(f"--{key}")
            # Always append value (boolean values become "true"/"false" strings)
            if isinstance(value, bool):
                result.append("true" if value else "false")
            else:
                result.append(str(value))
    return result


def parse_args_list_to_dict(args_list: List[str]) -> Dict[str, Any]:
    """Parse command-line argument list back to dictionary format.

    Args:
        args_list: List of arguments like ["--key", "value", "--flag"]

    Returns:
        Dictionary mapping keys to values
    """
    args_dict: Dict[str, Any] = {}
    i = 0
    while i < len(args_list):
        arg = args_list[i]
        if arg.startswith("--"):
            key = arg[2:]
            if i + 1 < len(args_list) and not args_list[i + 1].startswith("--"):
                value: Any = args_list[i + 1]
                if value == "true":
                    value = True
                elif value == "false":
                    value = False
                i += 2
            else:
                value = True
                i += 1
            args_dict[key] = value
        else:
            i += 1
    return args_dict


def dict_to_options_json(args_data: Union[Dict, List[str]]) -> Dict[str, Any]:
    """Convert args dict to optionsJson format (handles colon-separated keys and list input).

    If args_data is a list, it's first converted to dict, then processed.
    """
    # If already a list, parse it to dict first
    if isinstance(args_data, list):
        args_dict = parse_args_list_to_dict(args_data)
    else:
        args_dict = args_data

    result: Dict[str, Any] = {}
    for key, value in args_dict.items():
        if key == SPECIAL_ARG_MORE_ARGV:
            # moreArgv is not included in optionsJson
            continue
        # Handle colon-separated keys (nest them)
        if ":" in key:
            keyparts = key.split(":", 1)
            parent_key, child_key = keyparts[0], keyparts[1]
            if parent_key not in result:
                result[parent_key] = {}
            result[parent_key][child_key] = value
        else:
            result[key] = value
    return result


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
        "--no-report",
        help="Don't create test reports and crash tarballs",
        action="store_true",
    )

    return parser.parse_args()


def get_effective_option_value(
    job: TestJob, suite_index: Optional[int], attr_name: str, default=None
):
    """Get option value from suite if available, fall back to job, then default.

    Args:
        job: The test job
        suite_index: Suite index if splitting by suite, None otherwise
        attr_name: Name of the attribute to get (e.g., 'full', 'coverage', 'priority')
        default: Default value if not found

    Returns:
        The effective value for this option
    """
    # Check suite-level first
    if suite_index is not None and job.suites[suite_index].options:
        suite_value = getattr(job.suites[suite_index].options, attr_name, None)
        if suite_value is not None:
            return suite_value

    # Fall back to job-level
    job_value = getattr(job.options, attr_name, None)
    if job_value is not None:
        return job_value

    # Use default
    return default


def build_deployment_flags(deployment_type: DeploymentType) -> List[str]:
    """Build deployment type flags for legacy format.

    Args:
        deployment_type: The deployment type

    Returns:
        List of flag strings
    """
    flags = []
    if deployment_type is not None:
        if deployment_type == DeploymentType.SINGLE:
            flags.append("single")
        elif deployment_type == DeploymentType.CLUSTER:
            flags.append("cluster")
        elif deployment_type == DeploymentType.MIXED:
            flags.append("mixed")
    return flags


def build_option_flags(job: TestJob, suite_index: Optional[int]) -> List[str]:
    """Build full/coverage flags for legacy format.

    Args:
        job: The test job
        suite_index: Suite index if splitting by suite

    Returns:
        List of flag strings (e.g., ['full', '!coverage'])
    """
    flags = []

    # Add full/!full flag
    full_value = get_effective_option_value(job, suite_index, "full")
    if full_value is True:
        flags.append("full")
    elif full_value is False:
        flags.append("!full")

    # Add coverage flag
    coverage_value = get_effective_option_value(job, suite_index, "coverage")
    if coverage_value is True:
        flags.append("coverage")
    elif coverage_value is False:
        flags.append("!coverage")

    return flags


def build_args_for_job(
    job: TestJob, suite_index: Optional[int], is_full_run: bool
) -> List[str]:
    """Build command-line arguments list for a job.

    Args:
        job: The test job
        suite_index: If provided, build args for specific suite; otherwise for entire job
        is_full_run: Whether this is a full/nightly run

    Returns:
        List of command-line arguments
    """
    if suite_index is not None:
        # Single suite - combine job-level and suite-specific args
        suite = job.suites[suite_index]
        args = (
            dict_to_args_list(job.arguments.extra_args)
            if job.arguments and job.arguments.extra_args
            else []
        )
        if suite.arguments and suite.arguments.extra_args:
            args.extend(dict_to_args_list(suite.arguments.extra_args))
        return args

    # Multi-suite or single suite job - use job-level args plus optionsJson if needed
    args = (
        dict_to_args_list(job.arguments.extra_args)
        if job.arguments and job.arguments.extra_args
        else []
    )

    # For multi-suite jobs, add optionsJson
    if len(job.suites) > 1:
        # Filter suites based on full/nightly criteria
        criteria = FilterCriteria(
            full=is_full_run,
            nightly=False,  # Jenkins doesn't use nightly flag
            all_tests=False,
        )
        filtered_suites = filter_suites(job, criteria)

        options_json = []
        for suite in filtered_suites:
            # Convert suite arguments dict to optionsJson format
            suite_args = (
                dict_to_options_json(suite.arguments.extra_args)
                if suite.arguments and suite.arguments.extra_args
                else {}
            )
            options_json.append(suite_args)

        # Add optionsJson as a command-line argument
        args.extend(
            ["--optionsJson", json.dumps(options_json, separators=(",", ":"))]
        )

    return args


def convert_job_to_legacy_format(
    job: TestJob,
    deployment_type: DeploymentType,
    prefix: str = "",
    suite_index: Optional[int] = None,
    is_full_run: bool = False,
) -> dict:
    """Convert a TestJob from the clean data model to the legacy dict format."""
    # Determine job name
    job_name = job.suites[suite_index].name if suite_index is not None else job.name

    # Build flags
    flags = build_deployment_flags(deployment_type)
    flags.extend(build_option_flags(job, suite_index))

    # Build params
    params = {}

    # Get original deployment type from job (for determining if we should set type param)
    original_deployment_type = get_effective_option_value(job, suite_index, "deployment_type")

    for flag in flags:
        if flag == "cluster":
            # Only set type param if job originally had a deployment type
            if original_deployment_type is not None:
                params["type"] = "cluster"
        elif flag == "single":
            # Only set type param if job originally had a deployment type
            if original_deployment_type is not None:
                params["type"] = "single"
        elif flag == "mixed":
            params["type"] = "mixed"
        elif flag.startswith("!"):
            params[flag[1:]] = "False"
        else:
            params[flag] = "True"

    if job.options.buckets and job.options.buckets != "auto":
        params["buckets"] = job.options.buckets

    # Get effective size (suite can override job)
    # Default to medium for cluster/mixed, small otherwise (matching old controller logic)
    size = get_effective_option_value(job, suite_index, "size")
    if size:
        params["size"] = size.value
    else:
        # No explicit size - use old controller's default logic
        if deployment_type in (DeploymentType.CLUSTER, DeploymentType.MIXED):
            params["size"] = "medium"
        else:
            params["size"] = "small"

    # Get effective suffix (suite can override job)
    suffix = get_effective_option_value(job, suite_index, "suffix")
    if suffix:
        params["suffix"] = suffix

    # Get effective time_limit (suite can override job)
    time_limit = get_effective_option_value(job, suite_index, "time_limit")
    if time_limit:
        params["timeLimit"] = time_limit

    # Build args
    args = build_args_for_job(job, suite_index, is_full_run)

    # Get effective priority and parallelity
    is_cluster = deployment_type == DeploymentType.CLUSTER
    priority = get_effective_option_value(
        job, suite_index, "priority", DEFAULT_PRIORITY
    )
    params["priority"] = priority

    parallelity = get_effective_option_value(
        job,
        suite_index,
        "parallelity",
        DEFAULT_PARALLELITY_CLUSTER if is_cluster else DEFAULT_PARALLELITY_SINGLE,
    )
    params["parallelity"] = parallelity

    # Build suite field
    # For single-suite jobs, suite matches the job name
    # For multi-suite jobs, suite is a comma-separated list of all suite names
    if suite_index is not None:
        # Single suite job (flattened)
        suite_names = job_name
    else:
        # Multi-suite job - list all suite names
        suite_names = ",".join(suite.name for suite in job.suites)

    # Build arangosh_args
    # For single-suite jobs, use suite-level arangosh_args if available, otherwise job-level
    # For multi-suite jobs, use job-level arangosh_args
    if suite_index is not None and job.suites[suite_index].arguments:
        # Single suite - combine job-level and suite-level arangosh_args
        arangosh_args = (
            list(job.arguments.arangosh_args) if job.arguments else []
        )
        if job.suites[suite_index].arguments.arangosh_args:
            arangosh_args.extend(job.suites[suite_index].arguments.arangosh_args)
    else:
        # Multi-suite or no suite-specific args
        arangosh_args = (
            list(job.arguments.arangosh_args) if job.arguments else []
        )

    return {
        "name": job_name,
        "prefix": prefix,
        "priority": priority,
        "parallelity": parallelity,
        "flags": flags,
        "params": params,
        "args": args,
        "suite": suite_names,
        "arangosh_args": arangosh_args,
    }


def determine_deployment_configs(job: TestJob, args) -> List[DeploymentConfig]:
    """Determine which deployment configurations to test for this job.

    Logic:
    - Normal mode: Include single/mixed/None, exclude cluster
    - --cluster mode: Include cluster/mixed/None, exclude single
    - --single_cluster mode:
      - For single-suite jobs (flattened): create 2 jobs for mixed/None
      - For multi-suite jobs (with optionsJson): create 1 job (handles single/cluster internally)

    Args:
        job: The test job to configure
        args: Command-line arguments

    Returns:
        List of DeploymentConfig objects describing how to test this job
    """
    deployment_configs = []
    job_deployment = job.options.deployment_type
    is_multi_suite = len(job.suites) > 1

    if args.single_cluster:
        # Test both single and cluster
        if job_deployment == DeploymentType.CLUSTER:
            # Cluster-only tests: only run in cluster mode
            deployment_configs.append(
                DeploymentConfig(DeploymentType.CLUSTER, None, PREFIX_CLUSTER)
            )
        elif job_deployment == DeploymentType.SINGLE:
            # Single-only tests: only run in single mode
            deployment_configs.append(
                DeploymentConfig(DeploymentType.SINGLE, None, PREFIX_SINGLE)
            )
        elif is_multi_suite and job_deployment == DeploymentType.MIXED:
            # Multi-suite mixed jobs: create only 1 job (handles single/cluster internally via optionsJson)
            deployment_configs.append(
                DeploymentConfig(DeploymentType.MIXED, None, "")
            )
        else:
            # Single-suite mixed or unspecified tests: run in BOTH modes
            deployment_configs.append(
                DeploymentConfig(DeploymentType.SINGLE, None, PREFIX_SINGLE)
            )
            deployment_configs.append(
                DeploymentConfig(DeploymentType.CLUSTER, None, PREFIX_CLUSTER)
            )
    else:
        # Normal or --cluster mode: filter based on deployment type
        if args.cluster:
            # Cluster mode: exclude explicit single tests
            if job_deployment != DeploymentType.SINGLE:
                # Include cluster/mixed/None
                # Keep job's original type (even if None) for flag generation
                deployment_configs.append(
                    DeploymentConfig(job_deployment, DeploymentType.CLUSTER, "")
                )
        else:
            # Normal mode: exclude explicit cluster tests
            if job_deployment != DeploymentType.CLUSTER:
                # Include single/mixed/None
                # Keep job's original type (even if None) for flag generation
                deployment_configs.append(
                    DeploymentConfig(job_deployment, DeploymentType.SINGLE, "")
                )

    return deployment_configs


def flatten_jobs(test_def: TestDefinitionFile) -> List[TestJob]:
    """Flatten multi-suite jobs into simple single-suite jobs.

    For jobs with buckets:auto and multiple suites, creates new TestJob instances
    with one suite each. Suite-level options override job-level options.

    Args:
        test_def: Parsed test definition file

    Returns:
        List of TestJob instances, each with exactly one suite (or multiple suites with optionsJson)
    """
    flattened = []

    for job_name, job in test_def.jobs.items():
        # Skip driver tests (jobs with repository config)
        if job.repository is not None:
            continue

        # Check if this is a buckets:auto job with multiple suites
        if job.options.buckets == "auto" and len(job.suites) > 1:
            # Split into separate jobs, one per suite
            for suite in job.suites:
                # Create a new TestJob with just this suite
                new_job = deepcopy(job)
                new_job.name = suite.name
                new_job.suites = [suite]
                # Clear buckets:auto since we've already split
                new_job.options.buckets = None

                # Merge suite options into job options (suite overrides job)
                # This allows filters to work correctly on flattened jobs
                # Skip 'size' to avoid merging config_lib's auto-generated defaults
                if suite.options:
                    for field in suite.options.__dataclass_fields__:
                        if field == 'size':  # Size is handled by get_effective_option_value
                            continue
                        suite_value = getattr(suite.options, field)
                        if suite_value is not None:
                            setattr(new_job.options, field, suite_value)

                flattened.append(new_job)
        else:
            # Job as-is (might have multiple suites with optionsJson)
            flattened.append(job)

    return flattened


def apply_filters_and_deployment_configs(
    jobs: List[TestJob], args
) -> List[Tuple[TestJob, DeploymentConfig]]:
    """Apply filters and determine deployment configurations.

    Args:
        jobs: List of flattened jobs from Phase 1
        args: Command-line arguments

    Returns:
        List of (TestJob, DeploymentConfig) tuples
    """
    filtered = []

    for job in jobs:
        # Apply gtest filter
        if args.gtest and not job.name.startswith("gtest"):
            continue

        # Determine deployment configs for this job
        deployment_configs = determine_deployment_configs(job, args)

        # For each deployment config, check if job should be included
        for config in deployment_configs:
            # Build filter criteria
            criteria = build_filter_criteria(args, config)

            # Check if job should be included
            # Note: For flattened jobs, suite options are already merged into job options
            if should_include_job(job, criteria):
                filtered.append((job, config))

    return filtered


def convert_to_legacy_format(
    filtered_jobs: List[Tuple[TestJob, DeploymentConfig]], args
) -> List[dict]:
    """Convert filtered jobs to legacy dict format.

    Args:
        filtered_jobs: List of (TestJob, DeploymentConfig) tuples from Phase 2
        args: Command-line arguments

    Returns:
        List of legacy test dictionaries
    """
    legacy_tests = []

    for job, config in filtered_jobs:
        # For single-suite jobs, always use suite_index=0 to check suite options
        # For multi-suite jobs with optionsJson, use suite_index=None
        suite_index = 0 if len(job.suites) == 1 else None

        legacy_test = convert_job_to_legacy_format(
            job,
            config.deployment_type,
            config.prefix,
            suite_index=suite_index,
            is_full_run=args.full,
        )

        # In cluster filtering mode, add the cluster flag if not present
        if (
            config.deployment_requirement == DeploymentType.CLUSTER
            and "cluster" not in legacy_test["flags"]
        ):
            legacy_test["flags"].append("cluster")

        legacy_tests.append(legacy_test)

    return legacy_tests


def filter_and_convert_jobs(test_def: TestDefinitionFile, args) -> List[dict]:
    """
    Filter jobs based on command-line arguments and convert to legacy format.

    Args:
        test_def: Parsed test definition file
        args: Command-line arguments

    Returns:
        List of test dictionaries in legacy format
    """
    flattened = flatten_jobs(test_def)

    filtered = apply_filters_and_deployment_configs(flattened, args)

    legacy_tests = convert_to_legacy_format(filtered, args)

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
