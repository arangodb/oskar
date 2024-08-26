# Oskar

This is a set of scripts and a container image to conveniently run
tests for ArangoDB on linux. It only needs the `fish` shell, `git` and 
`Docker` installed on the system. For MacOSX it is possible to use
the build and test commands without `Docker`.

## Initial setup (Linux and MacOSX)

Place a pair of SSH keys in `~/.ssh/`
- private key: `id_rsa`
- public key: `id_rsa.pub`

Set appropriate permissions for the key files:
- `sudo chmod 600 ~/.ssh/id_rsa`
- `sudo chmod 600 ~/.ssh/id_rsa.pub`

Add the identity using the private key file:
- `ssh-add ~/.ssh/id_rsa`

Once you have cloned this repo and have set up `ssh-agent` with a
private key that is registered on *GitHub*, the initial setup is as
follows (in `fish`, so start a `fish` shell first if it is not your
login shell):

    cd oskar
    source helper.fish
    checkoutEnterprise             (or checkoutArangoDB if you do not have access)
    
This will pull the Docker image, start up a build and test container
and clone the ArangoDB source (optionally including the enterprise
code) into a subdirectory `work` in the current directory. It will
also show its current configuration.

### OpenSSL dependency build (macOS)

Oskar can build the OpenSSL version required for further building of ArangoDB
(based on particular branch requirement).

In order to use it `oskarOpenSSL` function has to be called prior to do
*Building ArangoDB*.

Otherwise `ownOpenSSL` is executed (by default) during oskar initialization.

In case of non-oskar OpenSSL preferred usage there is a need to set
OPENSSL_ROOT_DIR globally (in oskar session or through *Environment* capability).
It should be set to the installed (or manually built) OpenSSL binaries and
libraries.

There is no need to set OPENSSL_ROOT_DIR globally if a Homebrew package was
installed and it's version matches ArangoDB particular branch requirement. This
is automatically done by oskar in case of `ownOpenSSL` usage.

### Configurations and Secrets

Oskar uses some environments variable, see the chapter *Environment*.
You can create a file `config/environment.fish` to preset these variables.

For example

    set -xg COMMUNITY_DOWNLOAD_LINK "https://community.arangodb.com"
    set -xg ENTERPRISE_DOWNLOAD_LINK "https://enterprise.arangodb.com"

## Initial setup (Windows)

Once you have cloned this repo and have set up
`C:\Users\#USERNAME#\.ssh` with a private key that has access to
https://github.com/arangodb/enterprise, the initial setup is as
follows (in `powershell`, so start a `powershell`):

	Set-Location oskar
	Import-Module -Name .\helper.psm1
	checkoutEnterprise

## Choosing branches

Use

    switchBranches devel devel

where the first devel is the branch of the main repository and the
second one is the branch of the enterprise repository to
checkout. This will check out the branches and do a `git pull`
afterwards. You should not have local modifications in the repos
because they could be deleted.

## Building ArangoDB

You can then do

    buildStaticArangoDB

and add `cmake` options if you need like for example:

    buildStaticArangoDB -DUSE_IPO=Off

The first time this will take some time, but then the configured
`ccache` will make things a lot quicker. Once you have built for the
first time you can do

    makeStaticArangoDB

which does not throw away the `build` directory and should be even
faster.

## Building ArangoDB (Windows)

You can then do

    buildStaticArangoDB

for a static build or

    buildArangoDB
	
for a non-static build.

 
## Choices for the tests

For the compilation, you can choose between maintainer mode switched
on or off. Use `maintainerOff` or `maintainerOn` to switch.

Furthermore, you can switch the build mode between `Debug` and
`RelWithDebInfo`, use the commands `debugMode` and `releaseMode`.

Finally, if you have checked out the enterprise code, you can switch
between the community and enterprise editions using `community` and
`enterprise`.

Use `parallelism <number>` to specify which argument to `-j` should be
used in the `make` stage, the default is 64 on Linux and 8 on MacOSX.
Under Windows this setting is ignored.

At runtime, you can choose the storage engine (use the `mmfiles` or
`rocksdb` command), and you can select a test suite. Use the `cluster`,
`single` or `resilience` command.

Finally, you can choose which branch or commit to use for the build
with the command

    switchBranches <REV_IN_MAIN_REPO> <REV_IN_ENTERPRISE_REPO>

## Building and testing

Build ArangoDB with the current build options by issuing

    buildStaticArangoDB

and run the tests with the current runtime options using

    oskar

A report of the run will be shown on screen and a file with the
current timestamp will be put into the `work`
directory. Alternatively, you can combine these two steps in one by
doing

    oskar1

To run both single as well as cluster tests on the current configuration
do

    oskar2

To run both with both storage engines do

    oskar4

and, finally, to run everything for both the community as well as the
enterprise edition do

    oskar8

The test results as well as logs will be left in the `work` directory.

## Re-generate error files

After modifications to `lib/Basics/errors.dat`, you can update the generated files
that are based on it by running:

    shellInAlpineContainer

    cd /work/ArangoDB/build
    cmake --build . --target errorfiles

## Cleaning up

To erase the build directories and checked out sources, use

    clearWorkDir

After that, essentially all resources used by oskar are freed again.

# Reference Manual

## Environment Variables

## Select Branches

### switchBranches

    switchBranches <REV_IN_MAIN_REPO> <REV_IN_ENTERPRISE_REPO>

## Building

    buildStaticArangoDB

build static versions of executables. MacOSX does not support this
and will build dynamic executables instead.

    buildArangoDB

build dynamic versions of the executables

    maintainerOn
    maintainerOff

switch on/off maintainer mode when building

    debugMode
    releaseMode

build `Debug` (debugMode) or `RelWithDebInfo` (releaseMode)

    community
    enterprise

build enterprise edition (enterprise) or community version (community)

    parallelism <PARALLELSIM>

if supported, set number of concurrent builds to `PARALLELISM`

## Testing

`jenkins/helper/test_launch_controller.py` is used to control multiple test executions.

### Its dependencies over stock python3 are:
 - psutil to control subprocesses
 - py7zr (optional) to build 7z reports instead of tar.bz2

### It's reading these environment variables:
- `INNERWORKDIR` - as the directory to place the report files
- `WORKDIR` - used instead if `INNERWORKDIR` hasn't been set.
- `TEMP` - temporary directory if not `INNERWORKDIR`/ArangoDB
- `TMPDIR` and `TEMP` are passed to the executors.
- `TSHARK` passed as value to `--sniffProgram`
- `DUMPDEVICE` passed as value to `--sniffDevice`
- `SKIPNONDETERMINISTIC` passed on as value to `--skipNondeterministic` to the testing.
- `SKIPTIMECRITICAL` passed on as value to `--skipTimeCritical` to the testing.
- `BUILDMODE` passed on as value to `--buildType` to the testing.
- `DUMPAGENCYONERROR` passed on as value to `--dumpAgencyOnError` to the testing.
- `PORTBASE` passed on as value to `--minPort` and `--maxPort` (+99) to the testing. Defaults to 7000
- `SKIPGREY` passed on as value to `--skipGrey` to the testing.
- `ONLYGREY` passed on as value to `--onlyGrey` to the testing.
- `TIMELIMIT` is used to calculate the execution deadline starting point in time.
- `COREDIR` the directory to locate coredumps for crashes
- `LDAPHOST` to enable the tests with `ldap` flags.
- any parameter in `test-definition.txt` that starts with a `$` is expanded to its value.

### Its Parameters are:
 - `PATH/test-definition.txt` - (first parameter) test definitions file from the arangodb source tree
   (also used to locate the arangodb source)
 - `-f` `[launch|dump]` use `dump` for syntax checking of `test-definition.txt` instead of executing the tests
 - `--validate-only` don't run the tests
 - `--help-flags` list the flags which can be used in `test-definition.txt`:
    - `cluster`: this test requires a cluster
    - `single`: this test requires a single server
    - `full`: this test is only executed in full tests
    - `!full`: this test is only executed in non-full tests
    - `gtest`: only testsuites starting with 'gtest' are to be executed
    - `ldap`: ldap
    - `enterprise`: this test is only executed with the enterprise version
    - `!windows`: test is excluded from Windows runs
    - `!mac`: test is excluded from MacOS
    - `!arm`: test is excluded from ARM Linux / MacOS hosts 
 - `--cluster` filter `test-definition.txt` for all tests flagged as `cluster`
 - `--full` - all tests including those flagged as `full` are executed.
 - `--gtest` - only testsuites starting with 'gtest' are executed
 - `--all` - output unfiltered
 
### Syntax in `test-definition.txt`
Lines consist of these parts:
```
testingJsSuiteName flags params suffix -- args to testing.js
```
where 
- `flags` are listed above in `--help-flags`
- params are:
  - priority - sequence priority of test, 250 is the default.
  - parallelity - execution slots to book. defaults to 1, if cluster 4.
  - buckets - split testcases to be launched in concurent chunks
  Specifying a `*` in front of the number takes the default and multiplies it by the value.
- suffix - if a testsuite is launched several times, make it distinguishable
  like shell_aql => shell_aql_vst ; Bucket indexes are appended afterwards.
- `--` literally the two dashes to split the line at.
- `args to testing.js` - anything that `./scripts/unittest --help` would print you.

### job scheduling
To utilize all of the machines resources, tests can be run in parallel. The `execution_slots` are 
set to the number of the physical cores of the machine (not threads).
`parallelity` is used to add the currently expected load by the tests to be no more than `execution_slots`.

For managing each of these parallel executions of testing.js, worker threads are used. The workers
themselves will spawn a set of I/O threads to capture the output of testing.js into a report file.

The life cycle of a testrun will be as follows:

 - the environment variable `TIMELIMIT` defines a *deadline* to all the tests, how much seconds should be allowed.
 - tests are running in worker threads.
 - main thread keeps control, launches more worker threads, once machine bandwith permits, but only every 5s as closest to not overwhelm the machine while launching arangods.
 - tests themselves have their timeouts; `testing.js` will abort if they are reached.
 - workers have a progressive timeout, if it doesn't hear back from `testing.js` for 999999999s it will hard kill and abort. [currently high / not used!]
 - if workers have no output from `testing.js` they check whether the *deadline* is reached.
 - if the *deadline* is reached, `SIG_INT`[* nix] / `SIG_BREAK`[windows] is sent to `testing.js` to trigger its *deadline* feature.
 - the reached *deadline* will be indicated to the `testfailures.txt` report file and the logfile of the test in question.
 - with *deadline* engageged, `testing.js` can send no more subsequent requests, nor spawn processes => eventually testing will abort.
 - force shutdown of arangod Instances will reset the deadline, SIG_ABRT arangods, and try to do core dump analysis.
 - workers continue reading pipes from `testing.js`, but once no chars are comming, `waitpid()` checks with a 1s timout whether `testing.js` is done and exited.
 - if the worker reaches `180` counters of `waitpid()` invocations it will give up. It will hard kill `testing.js` and all other child processes it can find.
 - this should unblock the workers I/O threads, and they should exit.
 - the `waitpid()` on `testing.js` should exit, I/O threads should be joined, results should be passed up to the main thread.
 - so the workers still have a slugish interpretation of the *deadline*, giving them the chance to collect as much knowledge about the test execution as posible.
 - meanwhile the main thread has a *fixed* deadline: 5 minutes after the `TIMELIMIT` is reached.
 - if not all workers have indicated their exit before this final deadline:
   - the main thread will start killing any subprocesses of itself which it finds.
   - after this wait another 20s, to see whether the workers may have been unblocked by the killing
 - if not, it shouts "Geronimoooo" and takes the big shotgun, and force-terminates the python process which is running it. This will kill all threads as well and terminate the process.
 - if all workers have indicated their exit in time, their threads will be joined.
 - reports will be generated.

## Packaging

    makeRelease

creates all release packages.

### Requirements

You need to set the following environment variables:

    set -xg COMMUNITY_DOWNLOAD_LINK "https://community.arangodb.com"
    set -xg ENTERPRISE_DOWNLOAD_LINK "https://enterprise.arangodb.com"

The prefix for the link of the community and enterprise edition that
is used to construct the download link in the snippets.

    set -xg DOWNLOAD_SYNC_USER username:password

A github user that can download the syncer executable from github.

### Results

Under Linux:

- RPM, Debian and tar.gz
- server and client
- community and enterprise
- html snippets for debian, rpm, generic linux

Under macOS:

- DMG and tar.gz
- community and enterprise
- html snippets for macOS

## Internals
