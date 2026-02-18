const NATIVE_HOST = "com.myjo.host";

function buildContextMenus(notebooks) {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: "myjo-parent",
      title: "Send to MyJo",
      contexts: ["selection"]
    });

    for (const nb of notebooks) {
      chrome.contextMenus.create({
        id: "myjo-" + nb,
        parentId: "myjo-parent",
        title: nb,
        contexts: ["selection"]
      });
    }
  });
}

function refreshContextMenus() {
  chrome.runtime.sendNativeMessage(NATIVE_HOST, { action: "getNotebooks" }, (response) => {
    if (chrome.runtime.lastError || !response || !response.success) {
      console.error("MyJo: could not load notebooks for context menu");
      return;
    }
    buildContextMenus(response.notebooks);
  });
}

chrome.runtime.onInstalled.addListener(refreshContextMenus);
chrome.runtime.onStartup.addListener(refreshContextMenus);

// Handle context menu clicks
chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (!info.menuItemId.startsWith("myjo-") || info.menuItemId === "myjo-parent") return;

  const notebook = info.menuItemId.replace("myjo-", "");
  const text = info.selectionText;

  if (!text) return;

  chrome.runtime.sendNativeMessage(NATIVE_HOST, { notebook, text }, (response) => {
    if (chrome.runtime.lastError) {
      console.error("MyJo native messaging error:", chrome.runtime.lastError.message);
      return;
    }

    if (response && response.success) {
      console.log("MyJo: sent to", notebook);
    } else {
      console.error("MyJo error:", response ? response.error : "Unknown");
    }
  });
});
