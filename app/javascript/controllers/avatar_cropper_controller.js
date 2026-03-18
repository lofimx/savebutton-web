import { Controller } from "@hotwired/stimulus"
import Cropper from "cropperjs"

export default class extends Controller {
  static targets = ["input", "modal", "image", "preview", "croppedData"]

  connect() {
    this.cropper = null
  }

  disconnect() {
    this.destroyCropper()
  }

  openFilePicker() {
    this.inputTarget.click()
  }

  fileSelected(event) {
    const file = event.target.files[0]
    if (!file) return

    if (!file.type.startsWith('image/')) {
      alert('Please select an image file')
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      this.imageTarget.src = e.target.result
      this.showModal()
      this.initCropper()
    }
    reader.readAsDataURL(file)
  }

  showModal() {
    this.modalTarget.classList.add('active')
    document.body.style.overflow = 'hidden'
  }

  hideModal() {
    this.modalTarget.classList.remove('active')
    document.body.style.overflow = ''
    this.destroyCropper()
    this.inputTarget.value = ''
  }

  initCropper() {
    this.destroyCropper()

    this.cropper = new Cropper(this.imageTarget, {
      aspectRatio: 1,
      viewMode: 1,
      dragMode: 'move',
      autoCropArea: 1,
      cropBoxResizable: true,
      cropBoxMovable: true,
      guides: false,
      center: true,
      highlight: false,
      background: false,
      ready: () => {
        this.updatePreview()
      },
      crop: () => {
        this.updatePreview()
      }
    })
  }

  destroyCropper() {
    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
  }

  updatePreview() {
    if (!this.cropper || !this.hasPreviewTarget) return

    const canvas = this.cropper.getCroppedCanvas({
      width: 200,
      height: 200,
      imageSmoothingEnabled: true,
      imageSmoothingQuality: 'high'
    })

    if (canvas) {
      this.previewTarget.src = canvas.toDataURL()
    }
  }

  async save() {
    if (!this.cropper) return

    const canvas = this.cropper.getCroppedCanvas({
      width: 400,
      height: 400,
      imageSmoothingEnabled: true,
      imageSmoothingQuality: 'high'
    })

    if (!canvas) return

    canvas.toBlob(async (blob) => {
      const formData = new FormData()
      formData.append('avatar', blob, 'avatar.png')

      try {
        const response = await fetch('/account/avatar', {
          method: 'PATCH',
          body: formData,
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
          }
        })

        if (response.ok) {
          this.hideModal()
          window.location.reload()
        } else {
          const data = await response.json()
          alert(data.error || 'Failed to upload avatar')
        }
      } catch (error) {
        console.error('Upload error:', error)
        alert('Failed to upload avatar')
      }
    }, 'image/png', 0.9)
  }

  cancel() {
    this.hideModal()
  }
}
