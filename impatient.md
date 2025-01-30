# Setup on Ubuntu

Install fish, git, and docker.

```
    apt install fish git docker.io
```

Clone the Oskar repository.

```
    git clone git@github.com:arangodb/oskar.git
```

# Build of a specific branch

Initialize Oskar

```
    cd oskar
    git checkout release/arangodb-3.12.3 # use the correct branch for the version you want to build
    fish
    source helper.fish
```

If necessary, change the URL or organization of the source repository

```
    arangodbGitOrga fceller
    enterpriseGitOrga fceller
```


Checkout ArangoDB

```
    checkoutArangoDB
```

or

```
    checkoutEnterprise
```

Switch to the correct branch.

```
    switchBranches 3.12.3 3.12.3
```

Build ArangoDB and all related utilities.

# Build a specific target

Use the following to see all targets defined.

```
    makeArangoDB help
```

```
    buildStaticArangoDB
```

