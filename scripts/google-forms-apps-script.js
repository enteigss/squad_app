// Google Apps Script — paste into your Google Form's script editor
// (Form > three-dot menu > Script editor)
//
// After pasting, set up the trigger:
// 1. Click the clock icon (Triggers) in the left sidebar
// 2. Add Trigger > Choose function: onFormSubmit
// 3. Event source: From form > Event type: On form submit
// 4. Save

var CLOUD_FUNCTION_URL = "YOUR_CLOUD_FUNCTION_URL_HERE";

function onFormSubmit(e) {
  var r = e.namedValues;

  var payload = {
    email: val(r["What is your BU email? (so I can connect you with your group)"]),
    graduationYear: val(r["What is your graduation class?"]),
    genderPreference: val(r["Who are you looking to meet?"]),
    funActivities: val(r["What do you do for fun?"]),
    talkAboutForever: val(r["What topics could you talk about forever?"]),
    freeTime: val(r["When are you usually free? (No specific format necessary, answer this question however you want)"]),
    deepConversations: rating(r["How much do you enjoy deep conversations?"]),
    outdoors: rating(r["How much do you enjoy outdoor activities?"]),
    chilling: rating(r["How much do you enjoy just chilling?"]),
    competitiveGames: rating(r["How much do you enjoy competitive games? (video games, board games, mini golf etc.)"]),
    meals: rating(r["How much do you enjoy grabbing a meal?"]),
    nightsOut: rating(r["How much do you enjoy nights out?"]),
    phoneNumber: val(r["If you would prefer give me your number and I will text you instead (if you don't check your email much)"]),
  };

  var options = {
    method: "post",
    contentType: "application/json",
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  };

  var response = UrlFetchApp.fetch(CLOUD_FUNCTION_URL, options);
  Logger.log("Response: " + response.getContentText());
}

function val(arr) {
  return arr && arr.length > 0 ? arr[0].trim() : "";
}

function rating(arr) {
  var n = parseInt(val(arr), 10);
  return isNaN(n) ? 3 : n;
}
