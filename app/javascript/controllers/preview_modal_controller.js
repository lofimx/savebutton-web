import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "modal",
    "content",
    "title",
    "visitLink",
    "sidebar",
    "sidebarToggle",
    "sidebarToggleLabel",
    "sidebarContent",
    "tagsList",
    "tagInput",
    "noteEditor",
    "shareBtn",
    "downloadLink",
    "saveBtn",
  ];

  connect() {
    this.pollingInterval = null;
    this.currentTileElement = null;
    this.currentTags = [];
    this.originalTags = [];
    this.originalNote = "";
    this.sidebarVisible = true;
  }

  disconnect() {
    this.stopPolling();
  }

  open(event) {
    event.preventDefault();
    const tile = event.currentTarget;
    const url = tile.dataset.previewUrl;
    const filename = tile.dataset.previewFilename;
    const fileType = tile.dataset.previewType;
    const originalUrl = tile.dataset.previewOriginalUrl;
    const cacheUrl = tile.dataset.previewCacheUrl;
    const cacheStatusUrl = tile.dataset.cacheStatusUrl;
    const metaUrl = tile.dataset.metaUrl;
    const saveMetaUrl = tile.dataset.saveMetaUrl;
    const shareUrl = tile.dataset.shareUrl;

    this.currentTileElement = tile;
    this.currentMetaUrl = metaUrl;
    this.currentSaveMetaUrl = saveMetaUrl;
    this.currentShareUrl = shareUrl;

    // For bookmarks, show the original URL in the title if available
    // Decode filename for human-readable display (filenames are stored URL-encoded)
    this.titleTarget.textContent = originalUrl || decodeURIComponent(filename);

    // Show/hide visit link for bookmarks
    if (originalUrl) {
      this.visitLinkTarget.href = originalUrl;
      this.visitLinkTarget.classList.remove("hidden");
    } else {
      this.visitLinkTarget.classList.add("hidden");
    }

    // Set up download link
    if (this.hasDownloadLinkTarget) {
      this.downloadLinkTarget.href = url;
      this.downloadLinkTarget.download = decodeURIComponent(filename);
    }

    // Load content based on file type
    this.loadContent(url, fileType, cacheUrl, cacheStatusUrl);

    // Load metadata (tags and note)
    this.loadMeta();

    // Reset sidebar state
    this.sidebarVisible = true;
    this.updateSidebarVisibility();

    this.modalTarget.classList.add("active");
    document.body.style.overflow = "hidden";

    // Focus the modal for keyboard navigation
    this.modalTarget.focus();
  }

  close() {
    this.stopPolling();
    this.modalTarget.classList.remove("active");
    document.body.style.overflow = "";
    this.contentTarget.innerHTML = "";
    this.currentTileElement = null;
    this.currentTags = [];
    this.originalTags = [];
    this.originalNote = "";
    this.clearTagsAndNote();
  }

  cancel() {
    this.close();
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close();
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }

  toggleSidebar() {
    this.sidebarVisible = !this.sidebarVisible;
    this.updateSidebarVisibility();
  }

  updateSidebarVisibility() {
    if (this.hasSidebarTarget) {
      if (this.sidebarVisible) {
        this.sidebarTarget.classList.remove("collapsed");
        if (this.hasSidebarToggleLabelTarget) {
          this.sidebarToggleLabelTarget.textContent = "Hide Sidebar";
        }
      } else {
        this.sidebarTarget.classList.add("collapsed");
        if (this.hasSidebarToggleLabelTarget) {
          this.sidebarToggleLabelTarget.textContent = "Show Sidebar";
        }
      }
    }
  }

  // Load metadata from server
  async loadMeta() {
    if (!this.currentMetaUrl) return;

    try {
      const response = await fetch(this.currentMetaUrl);
      if (response.ok) {
        const data = await response.json();
        this.currentTags = data.tags || [];
        this.originalTags = [...this.currentTags];
        this.originalNote = data.note || "";

        this.renderTags();

        if (this.hasNoteEditorTarget) {
          this.noteEditorTarget.value = this.originalNote;
        }
      }
    } catch (error) {
      console.error("Failed to load metadata:", error);
    }
  }

  // Render tags in the UI
  renderTags() {
    if (!this.hasTagsListTarget) return;

    this.tagsListTarget.innerHTML = this.currentTags
      .map(
        (tag, index) => `
      <span class="tag" data-index="${index}">
        <span class="tag-text">${this.escapeHtml(tag)}</span>
        <button type="button" class="tag-remove" data-action="click->preview-modal#removeTag" data-index="${index}" aria-label="Remove tag">×</button>
      </span>
    `,
      )
      .join("");
  }

  // Add a new tag
  addTag(event) {
    event.preventDefault();

    if (!this.hasTagInputTarget) return;

    const tagValue = this.tagInputTarget.value.trim();
    if (tagValue && !this.currentTags.includes(tagValue)) {
      this.currentTags.push(tagValue);
      this.renderTags();
    }

    this.tagInputTarget.value = "";
    this.tagInputTarget.focus();
  }

  // Remove a tag
  removeTag(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10);
    if (!isNaN(index) && index >= 0 && index < this.currentTags.length) {
      this.currentTags.splice(index, 1);
      this.renderTags();
    }
  }

  // Clear tags and note UI
  clearTagsAndNote() {
    if (this.hasTagsListTarget) {
      this.tagsListTarget.innerHTML = "";
    }
    if (this.hasTagInputTarget) {
      this.tagInputTarget.value = "";
    }
    if (this.hasNoteEditorTarget) {
      this.noteEditorTarget.value = "";
    }
  }

  // Check if metadata has changed
  hasMetaChanges() {
    const currentNote = this.hasNoteEditorTarget
      ? this.noteEditorTarget.value
      : "";

    // Check if tags changed
    if (this.currentTags.length !== this.originalTags.length) return true;
    for (let i = 0; i < this.currentTags.length; i++) {
      if (this.currentTags[i] !== this.originalTags[i]) return true;
    }

    // Check if note changed
    if (currentNote !== this.originalNote) return true;

    return false;
  }

  // Save metadata
  async save() {
    if (!this.currentSaveMetaUrl) {
      this.close();
      return;
    }

    // Only save if there are changes
    if (!this.hasMetaChanges()) {
      this.close();
      return;
    }

    const currentNote = this.hasNoteEditorTarget
      ? this.noteEditorTarget.value
      : "";

    try {
      const response = await fetch(this.currentSaveMetaUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            ?.content,
        },
        body: JSON.stringify({
          tags: this.currentTags,
          note: currentNote,
        }),
      });

      if (response.ok) {
        this.close();
      } else {
        const data = await response.json();
        alert(data.error || "Failed to save metadata");
      }
    } catch (error) {
      console.error("Failed to save metadata:", error);
      alert("Failed to save metadata");
    }
  }

  // Share functionality - copy URL to clipboard
  async shareAnga() {
    if (!this.currentShareUrl) return;

    try {
      await navigator.clipboard.writeText(this.currentShareUrl);

      // Show feedback
      if (this.hasShareBtnTarget) {
        const originalText = this.shareBtnTarget.innerHTML;
        this.shareBtnTarget.innerHTML = `
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
          Copied!
        `;
        this.shareBtnTarget.classList.add("success");

        setTimeout(() => {
          this.shareBtnTarget.innerHTML = originalText;
          this.shareBtnTarget.classList.remove("success");
        }, 2000);
      }
    } catch (error) {
      console.error("Failed to copy share URL:", error);
      // Fallback: show the URL in an alert
      alert(`Share URL: ${this.currentShareUrl}`);
    }
  }

  loadContent(url, fileType, cacheUrl, cacheStatusUrl) {
    this.contentTarget.innerHTML =
      '<div class="preview-loading">Loading...</div>';

    switch (fileType) {
      case "note":
      case "text":
        this.loadText(url);
        break;
      case "image":
        this.loadImage(url);
        break;
      case "pdf":
        this.loadPdf(url);
        break;
      case "bookmark":
        this.loadBookmark(url, cacheUrl, cacheStatusUrl);
        break;
      default:
        this.contentTarget.innerHTML =
          '<div class="preview-unsupported">Preview not available for this file type.</div>';
    }
  }

  loadText(url) {
    fetch(url)
      .then((response) => response.text())
      .then((text) => {
        this.contentTarget.innerHTML = `<pre class="preview-text">${this.escapeHtml(text)}</pre>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="preview-error">Failed to load file.</div>';
      });
  }

  loadImage(url) {
    const img = document.createElement("img");
    img.src = url;
    img.alt = "Preview";
    img.className = "preview-image";
    img.onload = () => {
      this.contentTarget.innerHTML = "";
      this.contentTarget.appendChild(img);
    };
    img.onerror = () => {
      this.contentTarget.innerHTML =
        '<div class="preview-error">Failed to load image.</div>';
    };
  }

  loadPdf(url) {
    // Use an iframe to render PDF with browser's built-in PDF viewer
    this.contentTarget.innerHTML = `<iframe src="${url}" class="preview-pdf" title="PDF Preview"></iframe>`;
  }

  loadBookmark(url, cacheUrl, cacheStatusUrl) {
    // If we have a cached version, render it in an iframe
    if (cacheUrl) {
      this.contentTarget.innerHTML = `<iframe src="${cacheUrl}" class="preview-cached-page" title="Cached Webpage"></iframe>`;
      return;
    }

    // Otherwise, trigger caching and poll for completion
    if (cacheStatusUrl) {
      this.showCachingStatus(url);
      this.startPolling(cacheStatusUrl, url);
    } else {
      // Fallback for bookmarks without cache status URL
      this.showBookmarkFallback(url);
    }
  }

  showCachingStatus(url) {
    fetch(url)
      .then((response) => response.text())
      .then((text) => {
        this.contentTarget.innerHTML = `
          <div class="preview-bookmark">
            <div class="preview-caching-status">
              <div class="caching-spinner"></div>
              <p class="preview-bookmark-notice">Caching webpage...</p>
            </div>
            <pre class="preview-bookmark-content">${this.escapeHtml(text)}</pre>
          </div>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="preview-error">Failed to load bookmark.</div>';
      });
  }

  showBookmarkFallback(url) {
    fetch(url)
      .then((response) => response.text())
      .then((text) => {
        this.contentTarget.innerHTML = `<div class="preview-bookmark"><p class="preview-bookmark-notice">Webpage preview not available.</p><pre class="preview-bookmark-content">${this.escapeHtml(text)}</pre></div>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="preview-error">Failed to load bookmark.</div>';
      });
  }

  startPolling(cacheStatusUrl, previewUrl) {
    this.stopPolling();

    // Trigger caching immediately
    fetch(cacheStatusUrl)
      .then((response) => response.json())
      .then((data) => {
        this.handleCacheStatus(data, previewUrl);
      });

    // Poll every 2 seconds
    this.pollingInterval = setInterval(() => {
      fetch(cacheStatusUrl)
        .then((response) => response.json())
        .then((data) => {
          this.handleCacheStatus(data, previewUrl);
        })
        .catch(() => {
          // Ignore polling errors
        });
    }, 2000);
  }

  handleCacheStatus(data, previewUrl) {
    if (data.status === "cached") {
      this.onCacheComplete(data, previewUrl);
    } else if (data.status === "error") {
      this.onCacheError(data, previewUrl);
    }
    // If status is "pending", keep polling
  }

  stopPolling() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
      this.pollingInterval = null;
    }
  }

  onCacheComplete(data, previewUrl) {
    this.stopPolling();

    // Update the modal with the cached page
    if (data.cache_url) {
      this.contentTarget.innerHTML = `<iframe src="${data.cache_url}" class="preview-cached-page" title="Cached Webpage"></iframe>`;
    }

    // Update the tile to show the favicon and cache URL
    this.updateTile(data);
  }

  onCacheError(data, previewUrl) {
    this.stopPolling();

    // Show error message and fall back to showing the URL
    fetch(previewUrl)
      .then((response) => response.text())
      .then((text) => {
        this.contentTarget.innerHTML = `
          <div class="preview-bookmark">
            <div class="preview-cache-error">
              <p class="preview-bookmark-notice">Failed to cache webpage</p>
              <p class="preview-error-details">${this.escapeHtml(data.error || "Unknown error")}</p>
            </div>
            <pre class="preview-bookmark-content">${this.escapeHtml(text)}</pre>
          </div>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="preview-error">Failed to load bookmark.</div>';
      });
  }

  updateTile(data) {
    if (!this.currentTileElement) return;

    const tile = this.currentTileElement;

    // Update the tile's cache URL data attribute
    if (data.cache_url) {
      tile.dataset.previewCacheUrl = data.cache_url;
    }

    // Update the tile content to show favicon if available
    if (data.favicon_url) {
      const tileContent = tile.querySelector(".anga-tile-content");
      if (tileContent && tileContent.classList.contains("anga-tile-bookmark")) {
        const previousContent = tileContent.innerHTML;
        const img = document.createElement("img");
        img.src = data.favicon_url;
        img.className = "bookmark-favicon";
        img.alt = "Favicon";
        img.onerror = () => {
          tileContent.innerHTML = previousContent;
        };
        tileContent.innerHTML = "";
        tileContent.appendChild(img);
      }
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
