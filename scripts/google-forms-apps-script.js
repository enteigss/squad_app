// Google Apps Script — paste into your Google Form's script editor
// (Form > three-dot menu > Script editor)
//
// After pasting, set up the trigger:
// 1. Click the clock icon (Triggers) in the left sidebar
// 2. Add Trigger > Choose function: onFormSubmit
// 3. Event source: From form > Event type: On form submit
// 4. Save

var DEV_URL = "https://importsurveyresponse-4bufdcu3fq-uc.a.run.app";
var PROD_URL = "https://importsurveyresponse-mr2t4plsna-uc.a.run.app";

// Emails that go to BOTH dev and prod
var BOTH_EMAILS = [
  "enteigss@gmail.com",
  "jordan.anderson.green@gmail.com",
  "jordangr@bu.edu",
];

// Emails that go to dev ONLY
var DEV_ONLY_EMAILS = [
  "greenmichaeltodd@gmail.com",
  "green.wb.evan@gmail.com",
  "sheriese@gmail.com",
  "przem@gmail.com",
];

function getTargetUrls(email) {
  var lower = email.toLowerCase().trim();
  if (BOTH_EMAILS.indexOf(lower) !== -1) return [DEV_URL, PROD_URL];
  if (DEV_ONLY_EMAILS.indexOf(lower) !== -1) return [DEV_URL];
  return [PROD_URL];
}

function onFormSubmit(e) {
  var responses = {};
    e.response.getItemResponses().forEach(function(itemResponse) {
      responses[itemResponse.getItem().getTitle()] = itemResponse.getResponse();
    });
    var items = e.response.getItemResponses();
    for (var i = 0; i < items.length; i++) {
      Logger.log("Q: " + items[i].getItem().getTitle());
      Logger.log("A: " + items[i].getResponse());
      Logger.log("---");
    }

  var payload = {
    email: responses["What is your BU email? (so I can connect you with your group)"] || "",
    graduationYear: responses["What is your graduation class?"] || "",
    genderPreference: responses["Who are you looking to meet?"] || "",
    funActivities: responses["What do you like to do for fun?"] || "",
    talkAboutForever: responses["What topics could you talk about forever?"] || "",
    freeTime: responses["When are you usually free? (No specific format necessary, answer this question however you want)"] || "",
    deepConversations: parseInt(responses["How much do you enjoy deep conversations?"] || "3", 10),
    outdoors: parseInt(responses["How much do you enjoy outdoor activities?"] || "3", 10),
    chilling: parseInt(responses["How much do you enjoy just chilling?"] || "3", 10),
    competitiveGames: parseInt(responses["How much do you enjoy competitive games? (video games, board games, mini golf etc.)"] || "3", 10),
    meals: parseInt(responses["How much do you enjoy grabbing a meal?"] || "3", 10),
    nightsOut: parseInt(responses["How much do you enjoy nights out?"] || "3", 10),
    activityPreferencesElaboration: responses["If you want, tell us more about what you do or don't like to do with friends (Optional)"] || "",
    friendType: responses["How would you describe yourself as a friend?"] || "",
    friendTypeMatchWell: responses["What type of friend do you match well with?"] || "",
    friendTypeNoMatch: responses["What type of friend do you NOT match well with?"] || "",
    anythingElse: responses["Anything else that's important for us to know? (Optional)"] || "",
    phoneNumber: responses["If you you would prefer give me your number and I will text you instead (if you don't check your email much)."] || "",
  };

  var options = {
    method: "post",
    contentType: "application/json",
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  };

  Logger.log("Payload: " + JSON.stringify(payload, null, 2));

  var urls = getTargetUrls(payload.email);
  for (var i = 0; i < urls.length; i++) {
    var response = UrlFetchApp.fetch(urls[i], options);
    Logger.log("Response from " + urls[i] + ": " + response.getContentText());
  }
}

function val(arr) {
  return arr && arr.length > 0 ? arr[0].trim() : "";
}

function rating(arr) {
  var n = parseInt(val(arr), 10);
  return isNaN(n) ? 3 : n;
}
