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

  // All 6 activity keys
  var allActivities = [
    "deepConversations",
    "outdoors",
    "chilling",
    "competitiveGames",
    "meals",
    "nightsOut",
  ];

  // Parse excluded activities from checkbox question (comma-separated labels)
  var excludedRaw = responses["Which of these activities do you NOT enjoy?"] || "";
  var labelToKey = {
    "Deep conversations": "deepConversations",
    "Outdoor activities": "outdoors",
    "Just chilling": "chilling",
    "Competitive games": "competitiveGames",
    "Grabbing a meal": "meals",
    "Nights out": "nightsOut",
  };
  var excludedActivities = [];
  if (excludedRaw) {
    var labels = typeof excludedRaw === "string" ? excludedRaw.split(",") : excludedRaw;
    for (var j = 0; j < labels.length; j++) {
      var key = labelToKey[labels[j].trim()];
      if (key) excludedActivities.push(key);
    }
  }

  // Parse ranked activities from ranking question (ordered labels)
  var rankedRaw = responses["Rank the remaining activities from most to least enjoyed"] || "";
  var rankedActivities = [];
  if (rankedRaw) {
    var rankedLabels = typeof rankedRaw === "string" ? rankedRaw.split(",") : rankedRaw;
    for (var k = 0; k < rankedLabels.length; k++) {
      var rKey = labelToKey[rankedLabels[k].trim()];
      if (rKey && excludedActivities.indexOf(rKey) === -1) rankedActivities.push(rKey);
    }
  }

  // If no ranking provided, default to all non-excluded activities in original order
  if (rankedActivities.length === 0) {
    for (var m = 0; m < allActivities.length; m++) {
      if (excludedActivities.indexOf(allActivities[m]) === -1) {
        rankedActivities.push(allActivities[m]);
      }
    }
  }

  var payload = {
    email: responses["What is your BU email? (so I can connect you with your group)"] || "",
    graduationYear: responses["What is your graduation class?"] || "",
    genderPreference: responses["Who are you looking to meet?"] || "",
    funActivities: responses["What do you like to do for fun?"] || "",
    talkAboutForever: responses["What topics could you talk about forever?"] || "",
    freeTime: responses["When are you usually free? (No specific format necessary, answer this question however you want)"] || "",
    excludedActivities: excludedActivities,
    rankedActivities: rankedActivities,
    friendType: responses["What type of friend are you?"] || "",
    friendTypeMatchWell: responses["What type of friend do you match well with?"] || "",
    friendTypeNoMatch: responses["What type of friend do you NOT match well with?"] || "",
    anythingElse: responses["Anything else you'd like me to know?"] || "",
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
