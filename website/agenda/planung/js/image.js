if (window.namespace_image_js) throw "stop";
window.namespace_image_js = true;
"use strict";

class ImageManager {
    constructor() {
        this.commitHandler = null;
        this.target = null;
        this.permissions = {};
        this.container = null;
        this.projectId = null;
        this.studioId = null;
        this.isLoading = false;
        this.initialFilename = null;
    }

    async open(options, callback) {
        if (this.isLoading) return;
        this.isLoading = true;

        this.commitHandler = callback;
        this.target = options.target;
        this.projectId = options.project_id;
        this.studioId = options.studio_id;
        this.initialFilename = options.filename || null;

        const mainContent = document.querySelector("body > #content");
        if (mainContent) mainContent.style.display = "none";

        this.container = document.createElement('div');
        this.container.id = 'image-manager';
        document.body.appendChild(this.container);

        try {
            await this.init(options);
        } catch (err) {
            console.error("Image Manager failed:", err);
            this.close();
        } finally {
            this.isLoading = false;
        }
    }

    close() {
        const mainContent = document.querySelector("body > #content");
        if (mainContent) mainContent.style.display = 'flex';
        if (this.container) this.container.remove();
        this.container = null;
    }

    async init(options) {
        await loadLocalization('image');

        // Robust Event Delegation for Toolbar Actions
        this.container.addEventListener("click", (e) => {
            // Close Action
            if (e.target.id === 'abort-image-editor' || e.target.closest('#abort-image-editor')) {
                this.close();
            }
            // Search Action
            if (e.target.id === 'search-button' || e.target.closest('#search-button')) {
                this.handleSearch();
            }
            // Upload Trigger (if your CGI provides a static upload button)
            if (e.target.id === 'upload-button' || e.target.closest('#upload-button')) {
                const input = document.createElement('input');
                input.type = 'file';
                input.accept = 'image/*';
                input.onchange = (ev) => this.handleUpload(ev);
                input.click();
            }
        });

        const [perms] = await Promise.all([
            getJson('permissions.cgi', { project_id: this.projectId, studio_id: this.studioId }),
            loadHtmlFragment({
                url: 'image.cgi?' + new URLSearchParams({
                    action: 'show', project_id: this.projectId, studio_id: this.studioId
                }).toString(),
                target: '#image-manager'
            })
        ]);
        this.permissions = perms;

        const baseParams = { project_id: this.projectId, studio_id: this.studioId, action: 'get' };
        const [fileRes, seriesRes, searchRes] = await Promise.all([
            this.initialFilename ? getJson('image.cgi', { ...baseParams, filename: this.initialFilename }) : Promise.resolve({ images: [] }),
            options.series_id ? getJson('image.cgi', { ...baseParams, series_id: options.series_id }) : Promise.resolve({ images: [] }),
            options.search ? getJson('image.cgi', { ...baseParams, search: options.search }) : Promise.resolve({ images: [] })
        ]);

        const imageMap = new Map();
        [...searchRes.images, ...seriesRes.images, ...fileRes.images].forEach(img => {
            if (img && img.filename) imageMap.set(img.filename, img);
        });

        const finalImages = Array.from(imageMap.values());
        if (this.initialFilename) {
            finalImages.sort((a, b) => (a.filename === this.initialFilename ? -1 : b.filename === this.initialFilename ? 1 : 0));
        }

        this.renderImageList(finalImages);
    }

    renderImageList(images) {
        const listContainer = this.container.querySelector("div.images");
        if (!listContainer) return;

        listContainer.innerHTML = '';
        let targetThumbnail = null;

        images.forEach(image => {
            const div = document.createElement("div");
            div.className = "image inactive";
            div.id = `img_${image.id}`;
            div.dataset.filename = image.filename;
            const url = `show-image.cgi?project_id=${this.projectId}&studio_id=${this.studioId}&type=icon&filename=${encodeURIComponent(image.filename)}`;
            div.style.backgroundImage = `url('${url}')`;

            div.onclick = () => {
                this.setActiveThumbnail(div);
                this.loadImageEditor(image.filename);
            };

            if (this.initialFilename && image.filename === this.initialFilename) targetThumbnail = div;
            listContainer.append(div);
        });

        if (targetThumbnail) {
            targetThumbnail.click();
            setTimeout(() => targetThumbnail.scrollIntoView({ block: 'center', behavior: 'smooth' }), 100);
        } else if (images.length > 0) {
            listContainer.firstChild.click();
        }
    }

    setActiveThumbnail(elem) {
        this.container.querySelectorAll("div.image").forEach(img => {
            img.classList.remove("active");
            img.classList.add("inactive");
        });
        elem.classList.add("active");
        elem.classList.remove("inactive");
    }

    async loadImageEditor(filename) {
        const data = await getJson('image.cgi', {
            action: 'get', project_id: this.projectId, studio_id: this.studioId, filename: filename
        });

        if (!data.images || !data.images[0]) return;
        const image = data.images[0];

        this.setFormData(image);
        this.renderTools(image);
        this.attachLiveValidation(image);

        const loc = getLocalization();
        const props = this.container.querySelector('#image-properties');
        if (props) {
            props.innerHTML = `
                ${loc.label_created_at} ${image.created_at} ${loc.label_created_by} ${image.created_by}<br>
                ${loc.label_modified_at} ${image.modified_at} ${loc.label_modified_by} ${image.modified_by}<br>
                ${loc.label_link} {{${image.filename}|${image.name}}}<br>
            `;
        }

        const saveBtn = this.container.querySelector("#save-image");
        if (saveBtn) {
            saveBtn.innerHTML = `<sprite-icon name="save"></sprite-icon> ${loc.button_save || 'Save'}`;
            saveBtn.onclick = (e) => {
                e.preventDefault();
                this.saveImage(this.getFormData());
            };
        }
    }

    attachLiveValidation(image) {
        const licInput = this.getField('licence');
        const pubCheck = this.getField('public');

        if (licInput) {
            licInput.oninput = () => {
                image.licence = licInput.value;
                this.renderTools(image);
            };
        }
        if (pubCheck) {
            pubCheck.onchange = () => {
                image.public = pubCheck.checked ? 1 : 0;
                this.renderTools(image);
            };
        }
    }

    renderTools(image) {
        const tools = this.container.querySelector("#image-tools");
        if (!tools) return;
        tools.innerHTML = '';

        const loc = getLocalization();
        const isPublic = (image.public == 1 || image.public === "1");
        const hasLicense = !!(image.licence && String(image.licence).trim().length > 0);

        const createToolGroup = (warnText, button) => {
            const group = document.createElement('div');
            group.style.display = 'inline-flex';
            group.style.flexDirection = 'column';
            group.style.alignItems = 'center';
            group.style.marginRight = '10px';
            if (warnText) {
                const label = document.createElement('span');
                label.style.fontSize = '10px'; label.style.color = 'red'; label.style.fontWeight = 'bold';
                label.textContent = warnText;
                group.appendChild(label);
            }
            group.appendChild(button);
            return group;
        };

        if (isPublic) {
            const assignBtn = this.createBtn('assign', loc["label_assign_to_" + this.target] || `Assign`, () => {
                this.close();
                this.commitHandler(image);
            });
            const assignWarn = !hasLicense ? (loc.label_warn_unknown_licence || 'No License') : '';
            tools.appendChild(createToolGroup(assignWarn, assignBtn));
            tools.appendChild(createToolGroup('', this.createBtn('private', loc.button_depublish, () => this.togglePublish(image, 0))));
        } else {
            const pubWarn = loc['label_warn_not_public_' + this.target] || 'Not public';
            if (hasLicense) {
                tools.appendChild(createToolGroup(pubWarn, this.createBtn('public', loc.button_publish, () => this.togglePublish(image, 1))));
            } else {
                const dummyBtn = this.createBtn('public', loc.button_publish, () => {});
                dummyBtn.disabled = true; dummyBtn.style.opacity = '0.5';
                tools.appendChild(createToolGroup(loc.label_warn_unknown_licence || 'Missing License', dummyBtn));
            }
        }

        if (this.permissions.create_image) {
            tools.appendChild(createToolGroup('', this.createBtn('upload', loc.button_upload || 'Upload', () => {
                const input = document.createElement('input');
                input.type = 'file';
                input.accept = 'image/*';
                input.onchange = (e) => this.handleUpload(e);
                input.click();
            })));
        }

        if (this.permissions.delete_image) {
            tools.appendChild(createToolGroup('', this.createBtn('delete', loc.button_delete || 'Delete', () => {
                if (typeof commitAction === "function") {
                    commitAction("delete image", () => this.deleteImage(image.filename));
                } else if (confirm("Delete this image?")) {
                    this.deleteImage(image.filename);
                }
            })));
        }
    }

    async handleUpload(event) {
        const file = event.target.files[0];
        if (!file) return;
        const fd = new FormData();
        fd.append('action', "upload");
        fd.append('project_id', this.projectId);
        fd.append('studio_id', this.studioId);
        fd.append('upload', file.name);
        fd.append('licence', "");
        fd.append('description', "");
        fd.append('image', file);

        const res = await fetch('image-upload.cgi', { method: 'POST', body: fd });
        if (res.ok) {
            await this.handleSearch();
        }
    }

    async deleteImage(filename) {
        await getJson('image.cgi', {
            action: "delete", project_id: this.projectId, studio_id: this.studioId, filename: filename,
        });
        this.handleSearch();
    }

    getField(id) {
        return this.container.querySelector(`#${id}`) || this.container.querySelector(`[name="${id}"]`);
    }

    setFormData(image) {
        const f = (id) => this.getField(id);
        if (f('name')) f('name').value = image.name || '';
        if (f('description')) f('description').value = image.description || '';
        if (f('licence')) f('licence').value = image.licence || '';
        const pubCheckbox = f('public');
        if (pubCheckbox) pubCheckbox.checked = (image.public == 1 || image.public === "1");
        if (f('filename')) f('filename').value = image.filename || '';
        if (f('project_id')) f('project_id').value = image.project_id || 0;
        if (f('studio_id')) f('studio_id').value = image.studio_id || 0;
    }

    getFormData() {
        const f = (id) => this.getField(id);
        const pubCheckbox = f('public');
        return {
            project_id: f('project_id')?.value || 0,
            studio_id: f('studio_id')?.value || 0,
            name: f('name')?.value || '',
            description: f('description')?.value || '',
            licence: f('licence')?.value || '',
            public: (pubCheckbox && pubCheckbox.checked) ? 1 : 0,
            filename: f('filename')?.value || ''
        };
    }

    async togglePublish(image, status) {
        const data = this.getFormData();
        data.public = status;
        await this.saveImage(data);
    }

    async saveImage(image) {
        image.action = "save";
        const res = await postJson('image.cgi', image);
        if (res) {
            if (typeof showInfo === "function") showInfo(getLocalization().label_saved);
            await this.loadImageEditor(image.filename);
        }
    }

    async handleSearch() {
        const query = this.container.querySelector("input#search-field")?.value || "";
        const json = await getJson('image.cgi', {
            action: "get", project_id: this.projectId, studio_id: this.studioId, search: query
        });
        this.renderImageList(json.images);
    }

    createBtn(spriteName, text, cb) {
        const b = document.createElement('button');
        b.type = 'button';
        b.innerHTML = `<sprite-icon name="${spriteName}"></sprite-icon> ${text}`;
        b.onclick = (e) => { e.preventDefault(); cb(); };
        return b;
    }
}

// Ensure global existence immediately
window.ImageManager = new ImageManager();

function registerImageHandler() {
    document.querySelectorAll("button.select-image").forEach((btn) => {
        if (btn.dataset.hasImageHandler) return;
        btn.dataset.hasImageHandler = "true";

        btn.addEventListener("click", () => {
            window.ImageManager.open(btn.dataset, (image) => {
                const parent = btn.closest('div');
                const hiddenInput = parent.querySelector("input.image");
                const previewImg = parent.querySelector("#imagePreview");
                if (hiddenInput) hiddenInput.value = image.filename;
                if (previewImg) {
                    previewImg.src = `show-image.cgi?project_id=${image.project_id}&studio_id=${image.studio_id}&filename=${image.filename}&type=icon`;
                }
                btn.dataset.filename = image.filename;
            });
        });
    });
}

window.calcms ??= {};
window.calcms.init_image = async function(el) {
    await loadLocalization('image');
    registerImageHandler();
};