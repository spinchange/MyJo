const NATIVE_HOST = "com.myjo.host";

const NOTEBOOKS = [
  "default", "work", "personal", "projects", "devlog",
  "research", "trading", "health", "learning", "watchlist", "commonplace"
];

// Create context menus on install
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "myjo-parent",
    title: "Send to MyJo",
    contexts: ["selection"]
  });

  for (const nb of NOTEBOOKS) {
    chrome.contextMenus.create({
      id: "myjo-" + nb,
      parentId: "myjo-parent",
      title: nb,
      contexts: ["selection"]
    });
  }
});

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
