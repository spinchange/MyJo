const NATIVE_HOST = "com.myjo.host";
const notebookSelect = document.getElementById("notebook");
const sendBtn = document.getElementById("sendBtn");
const statusDiv = document.getElementById("status");

function showStatus(message, isError) {
  statusDiv.textContent = message;
  statusDiv.className = isError ? "error" : "success";
  setTimeout(() => { statusDiv.className = ""; statusDiv.style.display = "none"; }, 3000);
}

// Fetch notebooks from native host and populate dropdown
chrome.runtime.sendNativeMessage(NATIVE_HOST, { action: "getNotebooks" }, (response) => {
  if (chrome.runtime.lastError || !response || !response.success) {
    showStatus("Could not load notebooks", true);
    return;
  }

  notebookSelect.innerHTML = response.notebooks
    .map(nb => `<option value="${nb}">${nb}</option>`)
    .join("");

  // Restore last-used notebook
  chrome.storage.local.get("lastNotebook", (data) => {
    if (data.lastNotebook && notebookSelect.querySelector(`option[value="${data.lastNotebook}"]`)) {
      notebookSelect.value = data.lastNotebook;
    }
  });
});

// Save selection on change
notebookSelect.addEventListener("change", () => {
  chrome.storage.local.set({ lastNotebook: notebookSelect.value });
});

sendBtn.addEventListener("click", async () => {
  // Read clipboard via execCommand (most reliable in extension popups)
  const ta = document.createElement("textarea");
  document.body.appendChild(ta);
  ta.focus();
  document.execCommand("paste");
  const text = ta.value;
  document.body.removeChild(ta);

  if (!text || !text.trim()) {
    showStatus("Clipboard is empty", true);
    return;
  }

  const notebook = notebookSelect.value;
  chrome.storage.local.set({ lastNotebook: notebook });

  sendBtn.disabled = true;
  sendBtn.textContent = "Sending...";

  chrome.runtime.sendNativeMessage(NATIVE_HOST, { notebook, text }, (response) => {
    sendBtn.disabled = false;
    sendBtn.textContent = "Send Clipboard";

    if (chrome.runtime.lastError) {
      showStatus("Error: " + chrome.runtime.lastError.message, true);
      return;
    }

    if (response && response.success) {
      showStatus("Sent to " + notebook, false);
    } else {
      showStatus("Error: " + (response ? response.error : "Unknown"), true);
    }
  });
});
