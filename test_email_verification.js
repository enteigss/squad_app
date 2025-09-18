// Test script for email verification functions
// Run with: node test_email_verification.js

const https = require('https');

// Configuration
const PROJECT_ID = 'squad-7bc7e';
const EMULATOR_HOST = 'http://127.0.0.1:5001';
const PRODUCTION_HOST = 'https://us-central1-squad-7bc7e.cloudfunctions.net';

// Use emulator for testing (change to PRODUCTION_HOST for production testing)
const BASE_URL = EMULATOR_HOST;

// Test email - change this to your test email
const TEST_EMAIL = 'test@bu.edu';
const TEST_USER_ID = 'test-user-123';

// Mock Firebase auth token (for emulator testing)
const MOCK_AUTH_TOKEN = 'mock-token';

async function makeRequest(functionName, data, authToken = null) {
  const url = `${BASE_URL}/${PROJECT_ID}/us-central1/${functionName}`;

  const postData = JSON.stringify({
    data: data
  });

  const options = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData),
    }
  };

  if (authToken) {
    options.headers['Authorization'] = `Bearer ${authToken}`;
  }

  return new Promise((resolve, reject) => {
    const req = require(BASE_URL.startsWith('https') ? 'https' : 'http').request(url, options, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
      });

      res.on('end', () => {
        try {
          const result = JSON.parse(responseData);
          resolve({ status: res.statusCode, data: result });
        } catch (e) {
          resolve({ status: res.statusCode, data: responseData });
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    req.write(postData);
    req.end();
  });
}

async function testSendVerificationEmail() {
  console.log('\n🧪 Testing sendVerificationEmail...');

  try {
    const result = await makeRequest('sendVerificationEmail', {
      email: TEST_EMAIL
    }, MOCK_AUTH_TOKEN);

    console.log('Status:', result.status);
    console.log('Response:', JSON.stringify(result.data, null, 2));

    if (result.status === 200 && result.data.result?.success) {
      console.log('✅ Email verification sent successfully!');
      return true;
    } else {
      console.log('❌ Failed to send email verification');
      return false;
    }
  } catch (error) {
    console.log('❌ Error:', error.message);
    return false;
  }
}

async function testValidateVerificationCode(code) {
  console.log('\n🧪 Testing validateVerificationCode...');

  try {
    const result = await makeRequest('validateVerificationCode', {
      code: code
    }, MOCK_AUTH_TOKEN);

    console.log('Status:', result.status);
    console.log('Response:', JSON.stringify(result.data, null, 2));

    if (result.status === 200 && result.data.result?.success) {
      console.log('✅ Code validation successful!');
      return true;
    } else {
      console.log('❌ Code validation failed');
      return false;
    }
  } catch (error) {
    console.log('❌ Error:', error.message);
    return false;
  }
}

async function testInvalidCode() {
  console.log('\n🧪 Testing invalid code (should fail)...');

  try {
    const result = await makeRequest('validateVerificationCode', {
      code: '999999'  // Invalid code
    }, MOCK_AUTH_TOKEN);

    console.log('Status:', result.status);
    console.log('Response:', JSON.stringify(result.data, null, 2));

    if (result.status !== 200) {
      console.log('✅ Invalid code correctly rejected!');
      return true;
    } else {
      console.log('❌ Invalid code was accepted (this is bad!)');
      return false;
    }
  } catch (error) {
    console.log('✅ Invalid code correctly threw error:', error.message);
    return true;
  }
}

async function testUnauthenticated() {
  console.log('\n🧪 Testing unauthenticated request (should fail)...');

  try {
    const result = await makeRequest('sendVerificationEmail', {
      email: TEST_EMAIL
    }); // No auth token

    console.log('Status:', result.status);
    console.log('Response:', JSON.stringify(result.data, null, 2));

    if (result.status !== 200) {
      console.log('✅ Unauthenticated request correctly rejected!');
      return true;
    } else {
      console.log('❌ Unauthenticated request was accepted (this is bad!)');
      return false;
    }
  } catch (error) {
    console.log('✅ Unauthenticated request correctly threw error:', error.message);
    return true;
  }
}

async function runTests() {
  console.log('🚀 Starting Email Verification Function Tests');
  console.log('Base URL:', BASE_URL);
  console.log('Test Email:', TEST_EMAIL);

  const results = [];

  // Test 1: Send verification email
  results.push(await testSendVerificationEmail());

  // Test 2: Invalid code
  results.push(await testInvalidCode());

  // Test 3: Unauthenticated request
  results.push(await testUnauthenticated());

  // Summary
  const passed = results.filter(r => r).length;
  const total = results.length;

  console.log('\n📊 Test Summary:');
  console.log(`✅ Passed: ${passed}/${total}`);
  console.log(`❌ Failed: ${total - passed}/${total}`);

  if (passed === total) {
    console.log('🎉 All tests passed!');
  } else {
    console.log('⚠️  Some tests failed. Check the output above.');
  }

  console.log('\n📝 Manual Test:');
  console.log('1. Check your email for the verification code');
  console.log('2. Run: node test_email_verification.js validate <code>');
}

// Handle command line arguments
const args = process.argv.slice(2);
if (args[0] === 'validate' && args[1]) {
  testValidateVerificationCode(args[1]);
} else {
  runTests();
}