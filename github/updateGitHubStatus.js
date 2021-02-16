// Variables we need from jenkins env
const apiKey = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
// Variables that are job specific
const commitSha = "9ce7f4747557a130c0a19b303bd13d252a121c6a";
const targetUrl = "https://jenkins.arangodb.biz/test";                                    // TODO: implement url of the job
const context = "arangodb-matrix-full-pr";                                                // TODO: implement name of the job
const githubOwner = "";
const githubRepository = "";
const descriptionSuccess = "The build succeeded! Ready to be merged after valid review!"; // TODO: implement decsription of the job
const descriptionPending = "The build started. Waiting ...";
const descriptionFailure = "The build failed! Check the Details and take care of the failure!";
const baseUrl = "https://api.github.com/search/issues?q=";
const completeGetUrl = baseUrl + commitSha;
const https = require('https');
const postRequest = (postPath, apiKey, callback, postData) => {
  postData = JSON.stringify(postData);
  let options = {
    hostname: 'api.github.com',
    port: 443,
    path: postPath,
    method: 'POST',
    headers: {
      'authorization': 'token ' + apiKey,
      'user-agent': 'Awesome-Octocat-App',
      'Accept': 'application/vnd.github.v3+json',
      'Content-Length': postData.length,
      'Content-Type': 'application/json'
    }
  };
  console.log(options);
  let req = https.request(options, (res) => {
    res.on('data', (d) => {
      process.stdout.write(d);
    });
  });
  req.on('error', (e) => {
    console.error(e);
    console.log("Was not able to update status .. (this is not critical)");
    // TODO: mark update jenkins job as failed (this should not be critical)
  });
  req.write(postData);
  req.end();
};
const getRequest = (url, apiKey, callback) => {
  // api key here currently unused (as not needed by api here)
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
      callback(data);
    });
  }).on("error", (err) => {
    // In general - in cause of failure we will just not report to the GitHub PR at all
    // But this should not happen in general of course.
    console.log(err);
    console.log("Was not able to update status .. (this is not critical)");
    // TODO: mark update jenkins job as failed (this should not be critical)
  });
};
const callbackPost = (data) => {
  console.log("Finished post request, running callback now: ");
  console.log(JSON.parse(data));
}
// Main code starts here
const callbackGet = (data) => { // TODO: check if we can get rid of the GET req.
  let parsedGetResponse = JSON.parse(data);
  let htmlUrl = parsedGetResponse.items[0].html_url;
  let htmlUrlSplit = htmlUrl.split('/');
  let owner = htmlUrlSplit[3]; // TODO: check if we can extract from jenkins
  let repo = htmlUrlSplit[4]; // TODO: check if we can extract from jenkins
  let postPath = `/repos/${owner}/${repo}/statuses/${commitSha}`;
  let resultState = "failure"; // can be error, failure, pending, or success.
  let postData = {
    state: resultState,
    target_url: targetUrl,
    description: descriptionSuccess,
    context: context
  };
  postRequest(postPath, apiKey, callbackPost, postData);
}
// First, get the information we need (this may be dropped if we are able to READ
// 1.) REPO 2.) OWNER from Jenkins
getRequest(completeGetUrl, null, callbackGet);
// CallbackGet will then build and POST to GitHub the commit status
