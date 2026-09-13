"use strict";

function rewriteRequestHeader(e) {
  if (user) {
    let header1 = { "name": "X-DOMjudge-Login", "value": user };
    e.requestHeaders.push(header1);

    let header2 = { "name": "X-DOMjudge-Pass", "value": password_base64 };
    e.requestHeaders.push(header2);
  }
  return { requestHeaders: e.requestHeaders };
}


chrome.webRequest.onBeforeSendHeaders.addListener(
  rewriteRequestHeader,
  {urls: target.split(";")},
  ["blocking", "requestHeaders"]
);
