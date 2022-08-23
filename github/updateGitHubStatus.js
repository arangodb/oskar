const https = require('https');
const fs = require('fs');

const commitStatusResultFileName = 'commitStatusResult.json'
let commitExtraInformation = {};
let pullRequestExtraInformation = {
  url: undefined,
  info: undefined
};

// Variables we need from jenkins env:
const apiToken = process.env.API_TOKEN;       // well, a token :)
const repository = process.env.REPO;          // Format: arangodb/arangodb
const jobName = process.env.JOB_NAME;         // Format: jenkins-job-name
const targetUrl = process.env.JOB_ID;         // Format: https://www.abc.de/#123
const actionState = process.env.ACTION_STATE; // States: setPending, setError, setFailure, setSuccess
const githubBranchName = process.env.ARANGODB_BRANCH;
const githubCommitSHA = process.env.ARANGODB_COMMIT;


// error = bool, message = string, extra = object
const exitAndWriteResultToFile = (error, message, status, extra) => {
  let result = {
    error: error,
    message: message,
    extra: {}
  };

  if (!error) {
    // no error case
    // commit info area
    if (commitExtraInformation.hasOwnProperty('commit')) {
      result.extra.commit = commitExtraInformation.commit;
    }
    if (commitExtraInformation.hasOwnProperty('sha')) {
      result.extra.sha = commitExtraInformation.sha;
    }
    if (pullRequestExtraInformation.hasOwnProperty('url')) {
      result.url = pullRequestExtraInformation.url;
    }
    if (pullRequestExtraInformation.hasOwnProperty('info')) {
      result.info = pullRequestExtraInformation.info;
    }
    result.status = 'SUCCESS';
  } else {
    // error case
    if (!status) {
      // set error as default
      result.status = "FAIL";
    } else {
      result.status = status;
    }
  }

  // Note: if we want to supply additional information to file, here is the place (expecting an object)
  if (typeof extra === 'object') {
    for (let key in extra) {
      result.extra[key] = extra[key];
    }
  }

  fs.writeFileSync(`./${commitStatusResultFileName}`, JSON.stringify(result, null, 2), 'utf-8');

  if (error) {
    console.error(message);
    console.error(`Job is aborted. Wrote details into: ${commitStatusResultFileName}`);
    process.exit(1);
  }
  process.exit(0);
}

let actionStateIsValid = () => {
  const validActions = ['setPending', 'setError', 'setFailure', 'setSuccess'];
  return validActions.includes(actionState);
};
if (!actionStateIsValid()) {
  exitAndWriteResultToFile(true, "No valid JOB_ID env found!");
}
if (!jobName) {
  exitAndWriteResultToFile(true, "No valid JOB_NAME env found!");
}
if (!apiToken) {
  exitAndWriteResultToFile(true, "No valid API_TOKEN env found!");
}
if (!targetUrl) {
  exitAndWriteResultToFile(true, "No valid JOB_ID env found!");
}
if (!repository) {
  exitAndWriteResultToFile(true, "No valid REPO env found!", "FAIL_NO_BRANCH");
}
const githubOwner = repository.split('/')[0] || "arangodb";
const githubRepository = repository.split('/')[1] || "arangodb";

// TODO Future: We could add dates to messages here
const stateToDescriptionMap = {
  setPending: "The build started. Waiting ...",
  setSuccess: "The build succeeded! Ready to be merged after valid review!",
  setFailure: "The build failed! Check the details and take care of the failure!",
  setError: "The build errored! Check the details and take care of the error!"
};

const stateToGitHubStateMap = {
  setPending: "pending",
  setSuccess: "success",
  setFailure: "failure",
  setError: "error"
}

/*
 * Helper Methods Section Begin
 */

const erroredFinish = (errorCode, data) => {
  let message = `Job is not done! We've failed. Error code is: ${errorCode}, got response: ${JSON.stringify(data)}`;
  exitAndWriteResultToFile(true, message);
}

let validateResponseStatus = (info) => {
  let httpErrorCodes = [
    400, 401, 403, 404, 500, 502, 503, 504
  ];

  if (httpErrorCodes.includes(info.statusCode)) {
    return {error: true, code: info.statusCode}
  }

  return {error: false, code: info.statusCode};
}

// a bit dirty, but this will be filled first before we have the complete data in evaluatePostStatusResponse
let responseInformation = undefined;

let evaluatePostStatusResponse = (data) => {
  if (!responseInformation) {
    exitAndWriteResultToFile(true, "This is not allowed to happen! Got all data before first response!?");
  }
  let result = validateResponseStatus(responseInformation);
  if (result.error) {
    erroredFinish(result.code, data);
  }
  if (!data) {
    exitAndWriteResultToFile(true, "We did not receive any data from GitHub!");
  }

  // at this point we do have a success (data + positive status code)
  console.info(`Job is done. GitHub Status is updated. Wrote result into: ${commitStatusResultFileName}`);
  exitAndWriteResultToFile(false, `Properly set status to: ${actionState}`);

  // TODO Future Idea: We can also add modify labels: e.g. "Jenkins approved", "Jenkins failed" etc.
}

const postStatus = (postData, sha) => {
  const postPath = `/repos/${githubOwner}/${githubRepository}/statuses/${sha}`;
  let responseData = ''; // placeholder for our reponse data chunks

  postData = JSON.stringify(postData);
  let options = {
    hostname: 'api.github.com',
    port: 443,
    path: postPath,
    method: 'POST',
    headers: {
      'authorization': 'token ' + apiToken,
      'user-agent': 'Awesome-Octocat-App',
      'Accept': 'application/vnd.github.v3+json',
      'Content-Length': postData.length,
      'Content-Type': 'application/json'
    }
  };

  let req = https.request(options, (response) => {
    response.on('error', (e) => {
      exitAndWriteResultToFile(true, e.message);
    });
    response.on('end', () => {
      try {
        evaluatePostStatusResponse(JSON.parse(responseData));
      } catch (e) {
        exitAndWriteResultToFile(true, e.message);
      }
    });
  });

  req.on('response', response => {
    responseInformation = response;
    response.on('data', chunk => {
      responseData += chunk;
    });
  });

  req.write(postData);
  req.end();
};

const getRequest = (urlSuffix, callback, extraCallbackArgument) => {
  let url = 'https://api.github.com' + urlSuffix;
  let options = {
    headers: {
      'user-agent': 'Awesome-Octocat-App'
    }
  };
  https.get(url, options, (resp) => {
    let data = '';
    resp.on('data', (chunk) => {
      data += chunk;
    });
    resp.on('end', () => {
      if (extraCallbackArgument) {
        callback(data, extraCallbackArgument);
      } else {
        callback(data);
      }
    });
  }).on("error", (err) => {
    exitAndWriteResultToFile(true, `Failed to fetch commits from branch: ${githubBranchName}, tried URL: ${url}`);
  });
};

const buildPayload = () => {
  return payload = {
    state: stateToGitHubStateMap[actionState],
    target_url: targetUrl,
    description: stateToDescriptionMap[actionState],
    context: jobName
  };
};

/*
 * Helper Methods Section End
 */

const checkPRMethod = (prCheckData, sha) => {
  try {
    prCheckData = JSON.parse(prCheckData);
  } catch (e) {
    exitAndWriteResultToFile(true, "Could not parse server response: " + JSON.stringify(e));
  }

  // bool to check whether we won't find expected attributes we need
  let parseError = false;

  const parsePullRequestItems = (prCheckData) => {
    let infoItem;
    if (!prCheckData.hasOwnProperty('items')) {
      exitAndWriteResultToFile(true, 'Could not parse expected attribute: "items". Format might have been changed.');
    }

    let foundPullRequestsArray = prCheckData.items.slice().reverse();

    // iterate in reverse order, as the last items are the most relevant ones
    for (let pullRequestItem of foundPullRequestsArray) {
      // check if found item is valid (means it must be part of our given repository)
      if (pullRequestItem.url && pullRequestItem.url.indexOf(repository) != -1) {
        // means we've found a valid repository into our given repository
        infoItem = pullRequestItem;
        break;
      }
    };

    if (!infoItem) {
      // We've not found any valid pull request, therefore we cannot continue.
      // TODO Future: This is no actual error, we just do not need to continue with that script as it would be useless.
      // Check how to handle this case in the future.
      exitAndWriteResultToFile(true, "Found no related pull request. Exiting. Nothing to do.", 'FAIL_NO_PR');
    }

    if (infoItem.hasOwnProperty('state')) {
      if (infoItem.state !== 'open') {
        // we can abort - we found a PR, but this one is already closed
        exitAndWriteResultToFile(true, "We've only found a closed PR. Exiting.", "FAIL_NO_PR");
      }
    }

    if (infoItem.hasOwnProperty('body')) {
      // just additional information, let's not fail here
      pullRequestExtraInformation.info = infoItem.body;
    }

    if (infoItem.hasOwnProperty('pull_request')) {
      let pr = infoItem.pull_request;
      if (pr.hasOwnProperty('url')) {
        pullRequestExtraInformation.url = infoItem.pull_request.url;
      } else {
        parseError = true;
      }
    } else {
      parseError = true;
    }

    if (parseError) {
      exitAndWriteResultToFile(true, "Could not parse expected attributes. Format might have been changed.");
    }

    // if all good and PR found
    continueWithAction(sha);
  };

  if (prCheckData.hasOwnProperty('total_count')) {
    if (prCheckData.total_count >= 1) {
      parsePullRequestItems(prCheckData);
    } else {
      exitAndWriteResultToFile(true, "Could not read pull request details from GitHub Search API");
    }
  } else {
    // TODO Future: This is no actual error, we just do not need to continue with that script as it would be useless.
    // Check how to handle this case in the future.
    exitAndWriteResultToFile(true, "Found no related pull request. Exiting. Nothing to do.", 'FAIL_NO_PR');
  }
}

const checkPRExists = (sha) => {
  const queryString = encodeURIComponent(`${sha} repo:${repository}`);
  const checkPRExistencePath = `/search/issues?q=${queryString}`;
  getRequest(checkPRExistencePath, checkPRMethod, sha);
}

// Note: supplied sha must be valid here.
const continueWithAction = (sha) => {
  let postData = buildPayload();
  postStatus(postData, sha);
}

// Method to first initialize our specific sha parameter
const getCommitSha = () => {
  if (!githubBranchName) {
    exitAndWriteResultToFile(true, "No valid ARANGODB_BRANCH env found!");
  }

  // read branch name and find last commit SHA ID
  // Example: https://api.github.com/repos/arangodb/arangodb/commits?sha=bug-fix%2Fdevsup-720

  let getCommitShaUrl = `/repos/${githubOwner}/${githubRepository}/commits?sha=${encodeURIComponent(githubBranchName)}`;
  if (githubCommitSHA) { getCommitShaUrl += "&per_page=100" }
  getRequest(getCommitShaUrl, (data) => {
    if (data) {
      try {

        data = JSON.parse(data);
        try {
          let sha = "";
          if (githubCommitSHA) {
            for(i = 0; i < data.length; ++i) {
              if (data[i].hasOwnProperty("sha") && data[i].sha == githubCommitSHA) {
                sha = data[i].sha;
                commitExtraInformation = data[i];
              }
            }
          } else {
            commitExtraInformation = data[0];
            sha = data[0].sha; // as only last item + sha is out of interest here
          }
          if (!sha) {
            exitAndWriteResultToFile(true, "Could not parse commit SHA information!");
          } else {
            commitExtraInformation.sha = sha;
          }
          // We now do have all information we need, either supplied via Jenkins Environment or this GitHub API
          checkPRExists(sha);
        } catch (e) {
          exitAndWriteResultToFile(true,
            "Probably SHA not found - " + JSON.stringify(data, null, 2) + " : " + e.message
          );
        }
      } catch (e) {
        exitAndWriteResultToFile(true, e.message);
      }
    }
  });
}

// Actual program flow logic starts here => Will continue with inner callbacks
// Reason: Native https module does not support await/async. We don't want to include other dependencies here.
getCommitSha();

// Anyway, to get anyone a better starting point in the future (flow in case of success):
// getCommitSha() => continueWithAction(<sha>) => postStatus(<preparedPayload>)
