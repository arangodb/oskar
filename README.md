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

    buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem

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

Build ArangoDB with the current build options by issueing

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

build `Debug` (debugMode) or `RelWithDepInfo` (releaseMode)

    community
    enterprise

build enterprise edition (enterprise) or community version (community)

    parallelism <PARALLELSIM>

if supported, set numer of concurrent builds to `PARALLELISM`

## Testing

## Documentation

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

Under linux:

- RPM, Debian and tar.gz
- server and client
- community and enterprise
- html snippets for debian, rpm, generic linux

Under MacOSX:

- DMG and tar.gz
- community and enterprise
- html snippets for macosx

## Internals
