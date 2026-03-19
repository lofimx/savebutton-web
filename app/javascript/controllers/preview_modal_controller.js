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

    this.titleTarget.textContent = originalUrl || decodeURIComponent(filename);

    if (originalUrl) {
      this.visitLinkTarget.href = originalUrl;
      this.visitLinkTarget.classList.remove("hidden");
    } else {
      this.visitLinkTarget.classList.add("hidden");
    }

    if (this.hasDownloadLinkTarget) {
      this.downloadLinkTarget.href = url;
      this.downloadLinkTarget.download = decodeURIComponent(filename);
    }

    this.loadContent(url, fileType, cacheUrl, cacheStatusUrl);
    this.loadMeta();

    this.sidebarVisible = true;
    this.updateSidebarVisibility();

    this.modalTarget.showModal();
  }

  close() {
    this.stopPolling();
    this.modalTarget.close();
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

  renderTags() {
    if (!this.hasTagsListTarget) return;

    this.tagsListTarget.innerHTML = this.currentTags
      .map(
        (tag, index) => `
      <span class="tag" data-index="${index}">
        <span class="tag-text">${this.escapeHtml(tag)}</span>
        <button type="button" class="tag-remove" data-action="click->preview-modal#removeTag" data-index="${index}" aria-label="Remove tag">\u00d7</button>
      </span>
    `,
      )
      .join("");
  }

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

  removeTag(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10);
    if (!isNaN(index) && index >= 0 && index < this.currentTags.length) {
      this.currentTags.splice(index, 1);
      this.renderTags();
    }
  }

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

  hasMetaChanges() {
    const currentNote = this.hasNoteEditorTarget
      ? this.noteEditorTarget.value
      : "";

    if (this.currentTags.length !== this.originalTags.length) return true;
    for (let i = 0; i < this.currentTags.length; i++) {
      if (this.currentTags[i] !== this.originalTags[i]) return true;
    }

    if (currentNote !== this.originalNote) return true;

    return false;
  }

  async save() {
    if (!this.currentSaveMetaUrl) {
      this.close();
      return;
    }

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

  async shareAnga() {
    if (!this.currentShareUrl) return;

    try {
      await navigator.clipboard.writeText(this.currentShareUrl);

      if (this.hasShareBtnTarget) {
        const originalText = this.shareBtnTarget.innerHTML;
        this.shareBtnTarget.innerHTML = `
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
          Copied!
        `;

        setTimeout(() => {
          this.shareBtnTarget.innerHTML = originalText;
        }, 2000);
      }
    } catch (error) {
      console.error("Failed to copy share URL:", error);
      alert(`Share URL: ${this.currentShareUrl}`);
    }
  }

  loadContent(url, fileType, cacheUrl, cacheStatusUrl) {
    this.contentTarget.innerHTML =
      '<div class="flex items-center justify-center p-8 text-muted-foreground text-sm">Loading...</div>';

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
          '<div class="flex items-center justify-center p-8 text-muted-foreground text-sm">Preview not available for this file type.</div>';
    }
  }

  loadText(url) {
    fetch(url)
      .then((response) => response.text())
      .then((text) => {
        this.contentTarget.innerHTML = `<pre class="p-4 text-sm whitespace-pre-wrap break-words">${this.escapeHtml(text)}</pre>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="flex items-center justify-center p-8 text-destructive text-sm">Failed to load file.</div>';
      });
  }

  loadImage(url) {
    const img = document.createElement("img");
    img.src = url;
    img.alt = "Preview";
    img.className = "max-w-full max-h-full object-contain mx-auto";
    img.onload = () => {
      this.contentTarget.innerHTML = "";
      this.contentTarget.appendChild(img);
    };
    img.onerror = () => {
      this.contentTarget.innerHTML =
        '<div class="flex items-center justify-center p-8 text-destructive text-sm">Failed to load image.</div>';
    };
  }

  loadPdf(url) {
    this.contentTarget.innerHTML = `<iframe src="${url}" class="w-full h-full border-0" title="PDF Preview"></iframe>`;
  }

  loadBookmark(url, cacheUrl, cacheStatusUrl) {
    if (cacheUrl) {
      this.contentTarget.innerHTML = `<iframe src="${cacheUrl}" class="w-full h-full border-0" title="Cached Webpage"></iframe>`;
      return;
    }

    if (cacheStatusUrl) {
      this.showCachingStatus(url);
      this.startPolling(cacheStatusUrl, url);
    } else {
      this.showBookmarkFallback(url);
    }
  }

  showCachingStatus(url) {
    fetch(url)
      .then((response) => response.text())
      .then((text) => {
        this.contentTarget.innerHTML = `
          <div class="p-4">
            <div class="flex items-center gap-2 mb-4 text-sm text-muted-foreground">
              <svg class="animate-spin size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10" opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10" opacity="0.75"/></svg>
              <span>Caching webpage...</span>
            </div>
            <pre class="text-sm whitespace-pre-wrap break-words text-muted-foreground">${this.escapeHtml(text)}</pre>
          </div>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="flex items-center justify-center p-8 text-destructive text-sm">Failed to load bookmark.</div>';
      });
  }

  showBookmarkFallback(url) {
    fetch(url)
      .then((response) => response.text())
      .then((text) => {
        this.contentTarget.innerHTML = `<div class="p-4"><p class="text-sm text-muted-foreground mb-4">Webpage preview not available.</p><pre class="text-sm whitespace-pre-wrap break-words text-muted-foreground">${this.escapeHtml(text)}</pre></div>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="flex items-center justify-center p-8 text-destructive text-sm">Failed to load bookmark.</div>';
      });
  }

  startPolling(cacheStatusUrl, previewUrl) {
    this.stopPolling();

    fetch(cacheStatusUrl)
      .then((response) => response.json())
      .then((data) => {
        this.handleCacheStatus(data, previewUrl);
      });

    this.pollingInterval = setInterval(() => {
      fetch(cacheStatusUrl)
        .then((response) => response.json())
        .then((data) => {
          this.handleCacheStatus(data, previewUrl);
        })
        .catch(() => {});
    }, 2000);
  }

  handleCacheStatus(data, previewUrl) {
    if (data.status === "cached") {
      this.onCacheComplete(data, previewUrl);
    } else if (data.status === "error") {
      this.onCacheError(data, previewUrl);
    }
  }

  stopPolling() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
      this.pollingInterval = null;
    }
  }

  onCacheComplete(data, previewUrl) {
    this.stopPolling();

    if (data.cache_url) {
      this.contentTarget.innerHTML = `<iframe src="${data.cache_url}" class="w-full h-full border-0" title="Cached Webpage"></iframe>`;
    }

    this.updateTile(data);
  }

  onCacheError(data, previewUrl) {
    this.stopPolling();

    fetch(previewUrl)
      .then((response) => response.text())
      .then((text) => {
        this.contentTarget.innerHTML = `
          <div class="p-4">
            <div class="mb-4">
              <p class="text-sm text-destructive">Failed to cache webpage</p>
              <p class="text-xs text-muted-foreground">${this.escapeHtml(data.error || "Unknown error")}</p>
            </div>
            <pre class="text-sm whitespace-pre-wrap break-words text-muted-foreground">${this.escapeHtml(text)}</pre>
          </div>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="flex items-center justify-center p-8 text-destructive text-sm">Failed to load bookmark.</div>';
      });
  }

  updateTile(data) {
    if (!this.currentTileElement) return;

    const tile = this.currentTileElement;

    if (data.cache_url) {
      tile.dataset.previewCacheUrl = data.cache_url;
    }

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
