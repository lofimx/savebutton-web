import { Controller } from "@hotwired/stimulus";
import * as bootstrap from "bootstrap";

export default class extends Controller {
  static targets = ["modal", "content", "input", "dropzone", "saveButton", "status"];

  connect() {
    this.bsModal = new bootstrap.Modal(this.modalTarget);
  }

  open() {
    this.bsModal.show();
    // Focus input after modal is shown
    this.modalTarget.addEventListener(
      "shown.bs.modal",
      () => this.inputTarget.focus(),
      { once: true },
    );
  }

  close() {
    this.bsModal.hide();
    this.inputTarget.value = "";
    this.hideStatus();
  }

  dragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = "copy";
  }

  dragEnter(event) {
    event.preventDefault();
    this.dropzoneTarget.classList.add("drag-over");
  }

  dragLeave(event) {
    event.preventDefault();
    if (!this.dropzoneTarget.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove("drag-over");
    }
  }

  drop(event) {
    event.preventDefault();
    this.dropzoneTarget.classList.remove("drag-over");

    const files = event.dataTransfer.files;
    const text = event.dataTransfer.getData("text/plain");

    if (files.length > 0) {
      this.uploadFiles(files);
    } else if (text) {
      this.inputTarget.value = text;
      this.save();
    }
  }

  async save() {
    const text = this.inputTarget.value.trim();
    if (!text) {
      this.showStatus("Please enter a note or bookmark", "error");
      return;
    }

    this.saveButtonTarget.disabled = true;
    this.showStatus("Saving...", "info");

    try {
      const isBookmark = this.isUrl(text);
      const response = await fetch("/app/anga", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
        },
        body: JSON.stringify({
          content: text,
          type: isBookmark ? "bookmark" : "note",
        }),
      });

      if (response.ok) {
        this.showStatus("Saved!", "success");
        setTimeout(() => {
          this.close();
          window.location.reload();
        }, 500);
      } else {
        const error = await response.text();
        this.showStatus(`Failed to save: ${error}`, "error");
      }
    } catch (error) {
      this.showStatus(`Failed to save: ${error.message}`, "error");
    } finally {
      this.saveButtonTarget.disabled = false;
    }
  }

  async uploadFiles(files) {
    this.saveButtonTarget.disabled = true;
    this.showStatus(`Uploading ${files.length} file(s)...`, "info");

    let successCount = 0;
    let errorCount = 0;

    for (const file of files) {
      try {
        const formData = new FormData();
        formData.append("file", file);

        const response = await fetch("/app/anga", {
          method: "POST",
          headers: {
            "X-CSRF-Token": this.csrfToken,
          },
          body: formData,
        });

        if (response.ok) {
          successCount++;
        } else {
          errorCount++;
        }
      } catch (error) {
        errorCount++;
      }
    }

    this.saveButtonTarget.disabled = false;

    if (errorCount === 0) {
      this.showStatus(`Uploaded ${successCount} file(s)!`, "success");
      setTimeout(() => {
        this.close();
        window.location.reload();
      }, 500);
    } else {
      this.showStatus(
        `Uploaded ${successCount}, failed ${errorCount}`,
        "error",
      );
    }
  }

  isUrl(text) {
    return /^https?:\/\//i.test(text);
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content;
  }

  showStatus(message, type) {
    this.statusTarget.textContent = message;
    this.statusTarget.className = `add-modal-status add-modal-status-${type}`;
    this.statusTarget.classList.remove("d-none");
  }

  hideStatus() {
    this.statusTarget.classList.add("d-none");
  }
}
