#!/usr/bin/env fish
pushd $INNERWORKDIR/ArangoDB
and echo "Generating examples"
and bash -c ./utils/generateExamples.sh
and echo "Generating swagger"
and bash -c ./utils/generateSwagger.sh
or begin echo "FAILED!"; popd; exit 1; end
popd