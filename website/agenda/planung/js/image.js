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
        this.isUploadMode = false;
        this.currentSearchQuery = "";
    }

    // --- Factory Helpers ---
    _el(tag, props = {}, children = []) {
        const el = document.createElement(tag);
        const { dataset, style, ...rest } = props;
        Object.assign(el, rest);
        if (dataset) Object.assign(el.dataset, dataset);
        if (style) Object.assign(el.style, style);
        children.forEach(child => {
            if (!child) return;
            if (typeof child === "string") el.insertAdjacentHTML("beforeend", child);
            else el.appendChild(child);
        });
        return el;
    }

    _btn(icon, text, cb, cls = "") {
        return this._el("button", {
            type: "button",
            className: cls,
            onclick: (e) => { e.preventDefault(); cb(e); }
        }, [`<sprite-icon name='${icon}'></sprite-icon> ${text}`]);
    }

    // --- Core Logic ---
    async open(options, callback) {
        if (this.isLoading) return;
        this.isLoading = true;

        this.commitHandler = callback;
        this.target = options.target;
        this.projectId = options.project_id;
        this.studioId = options.studio_id;
        this.initialFilename = options.filename || null;
        this.currentSearchQuery = options.search || "";
        this.isUploadMode = false;

        const mainContent = document.querySelector("body > #content");
        if (mainContent) mainContent.style.display = "none";

        this.container = this._el("div", { id: "image-manager" });
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
        if (mainContent) mainContent.style.display = "flex";
        if (this.container) this.container.remove();
        this.container = null;
    }

    async init(options) {
        await loadLocalization("image");

        this.container.addEventListener("click", (e) => {
            if (e.target.closest("#abort-image-editor")) this.close();
            if (e.target.closest("#search-button")) this.handleSearch();
            if (e.target.closest("#sidebar-upload-btn")) this.prepareUpload();
        });

        const urlParams = new URLSearchParams({
            action: "show", project_id: this.projectId, studio_id: this.studioId
        }).toString();

        const [perms] = await Promise.all([
            getJson("permissions.cgi", { project_id: this.projectId, studio_id: this.studioId }),
            loadHtmlFragment({ url: "image.cgi?" + urlParams, target: "#image-manager" })
        ]);
        this.permissions = perms;

        const searchInput = this.container.querySelector("input#search-field"); 
        if (searchInput) { 
            searchInput.value = this.currentSearchQuery; 
            searchInput.addEventListener('keypress', (event) => { 
                if (event.key === 'Enter') {
                    event.preventDefault(); 
                    this.handleSearch(); 
                }
            });
        }

        await this.loadData(this.currentSearchQuery);
    }

    async handleSearch() {
        const searchInput = this.container.querySelector("input#search-field");
        this.currentSearchQuery = searchInput ? searchInput.value.trim() : "";
        await this.loadData(this.currentSearchQuery);
    }

    async loadData(query) {
        const params = { action: "get", project_id: this.projectId, studio_id: this.studioId };
        if (query) params.search = query;
        const json = await getJson("image.cgi", params);
        await this.processAndRender(json);
    }

    async processAndRender(json) {
        let images = (json && json.images) ? json.images : [];
        images = [...new Map(json.images.map(item => [item.filename, item])).values()];

        if (this.initialFilename) {
            const index = images.findIndex(img => img.filename === this.initialFilename);
            if (index > -1) {
                images.unshift(images.splice(index, 1)[0]);
            } else {
                const singleJson = await getJson("image.cgi", {
                    action: "get", project_id: this.projectId, studio_id: this.studioId, filename: this.initialFilename
                });
                if (singleJson?.images?.[0]) images.unshift(singleJson.images[0]);
            }
        }

        if (this.permissions.create_image) {
            images.unshift({ filename: "__NEW__", id: "new", name: "New Upload" });
        }

        this.renderImageList(images);
    }

    renderImageList(images) {
        const listContainer = this.container.querySelector("div.images");
        if (!listContainer) return;
        listContainer.innerHTML = "";

        let targetThumbnail = null;

        images.forEach(image => {
            const isNew = image.filename === "__NEW__";
            const url = `show-image.cgi?project_id=${this.projectId}&studio_id=${this.studioId}&type=icon&filename=${encodeURIComponent(image.filename)}`;

            const div = this._el("div", {
                id: "img_" + image.id,
                className: `image inactive ${isNew ? "upload-placeholder" : ""}`,
                dataset: { filename: image.filename },
                style: isNew 
                    ? { backgroundColor: "#e0e0e0", display: "flex" } 
                    : { backgroundImage: `url('${url}')` },
                onclick: () => {
                    this.setActiveThumbnail(div);
                    isNew ? this.prepareUpload() : this.loadImageEditor(image.filename);
                }
            }, isNew ? ["<sprite-icon name='upload' style='margin:auto;'></sprite-icon>"] : []);

            if ((this.isUploadMode && isNew) || (!this.isUploadMode && image.filename === this.initialFilename)) {
                targetThumbnail = div;
            }
            listContainer.append(div);
        });

        if (this.isUploadMode) this.toggleImageIconsVisibility(false);
        if (targetThumbnail) targetThumbnail.click();
        else if (listContainer.firstChild) listContainer.firstChild.click();
    }

    setActiveThumbnail(elem) {
        this.container.querySelectorAll("div.image").forEach(img => {
            img.classList.replace("active", "inactive");
        });
        elem.classList.replace("inactive", "active");
    }

    prepareUpload() {
        this.isUploadMode = true;
        const loc = getLocalization();
        this.toggleSearchVisibility(false);
        this.toggleImageIconsVisibility(false);
        this.setFormData({ name: "", description: "", licence: "", public: 0 });

        const props = this.container.querySelector("#image-properties");
        if (props) {
            props.innerHTML = "";
            props.append(
                this._el("b", { style: { color: "var(--brand-color)" }, innerText: loc.label_new_upload || "New Image Upload" }),
                this._el("br"),
                this._el("span", { innerText: loc.label_select_file_hint || "Select a file using the button below" })
            );
        }

        const tools = this.container.querySelector("#image-tools");
        if (tools) tools.innerHTML = "";

        const saveBtn = this.container.querySelector("#save-image");
        if (saveBtn) {
            saveBtn.innerHTML = "";
            saveBtn.append(
                this._btn("upload", loc.button_upload || "Upload", () => this.triggerFilePicker(), "primary"),
                this._el("span", { style: { marginLeft: "10px" } }),
                this._btn("close", loc.button_cancel || "Cancel", () => {
                    this.isUploadMode = false;
                    this.toggleImageIconsVisibility(true);
                    const firstImg = this.container.querySelector(".image:not(.upload-placeholder)");
                    this.initialFilename ? this.loadImageEditor(this.initialFilename) : firstImg?.click();
                })
            );
        }
    }

    toggleSearchVisibility(visible) {
        const field = this.container.querySelector("#search-field")?.parentElement;
        const btn = this.container.querySelector("#search-button");
        if (field) field.style.display = visible ? "" : "none";
        if (btn) btn.style.display = visible ? "" : "none";
    }

    toggleImageIconsVisibility(visible) {
        this.container.querySelectorAll(".image:not(.upload-placeholder)").forEach(icon => {
            icon.style.display = visible ? "" : "none";
        });
    }

    triggerFilePicker() {
        let input = document.getElementById("hidden-upload-input");
        if (!input) {
            input = this._el("input", { type: "file", id: "hidden-upload-input", accept: "image/*", style: { display: "none" } });
            document.body.appendChild(input);
        }
        input.onchange = (e) => {
            if (e.target.files?.[0]) this.processUpload(e.target.files[0]);
            input.value = "";
        };
        input.click();
    }

    async processUpload(file) {
        const fd = new FormData();
        fd.append("project_id", this.projectId);
        fd.append("studio_id", this.studioId);
        fd.append("action", "upload");
        fd.append("upload", file.name);
        fd.append("licence", this.getField("licence").value);
        fd.append("description", this.getField("description").value);
        fd.append("image", file);

        const res = await fetch("image-upload.cgi", { method: "POST", body: fd });
        if (res.ok) {
            const result = await res.json();
            this.isUploadMode = false;
            this.initialFilename = result.filename || file.name;
            await this.loadData(this.currentSearchQuery);
        }
    }

    async loadImageEditor(filename) {
        this.toggleSearchVisibility(true);
        this.toggleImageIconsVisibility(true);

        const data = await getJson("image.cgi", {
            action: "get", project_id: this.projectId, studio_id: this.studioId, filename: filename
        });

        if (!data?.images?.[0]) return;
        const image = data.images[0];

        this.setFormData(image);
        this.renderTools(image);
        this.attachLiveValidation(image);

        const loc = getLocalization();
        const props = this.container.querySelector("#image-properties");
        if (props) {
            props.innerHTML = `${loc.label_created_at} <span class="fmt-datetime">${image.created_at}</span> ${loc.label_created_by} ${image.created_by}<br>` +
                `${loc.label_modified_at} <span class="fmt-datetime">${image.modified_at}</span> ${loc.label_modified_by} ${image.modified_by}<br>` +
                `${loc.label_link} <copyable-id>{{${image.filename}|${image.name}}}</copyable-id><br>`;
            formatDates(props);
        }

        const saveBtn = this.container.querySelector("#save-image");
        if (saveBtn) {
            saveBtn.innerHTML = "";
            saveBtn.append(this._btn("save", loc.button_save || "Save", () => this.saveImage(this.getFormData())));
        }
    }

    attachLiveValidation(image) {
        const licInput = this.getField("licence");
        const pubCheck = this.getField("public");
        if (licInput) licInput.oninput = () => { image.licence = licInput.value; this.renderTools(image); };
        if (pubCheck) pubCheck.onchange = () => { image.public = pubCheck.checked ? 1 : 0; this.renderTools(image); };
    }

    renderTools(image) {
        const tools = this.container.querySelector("#image-tools");
        if (!tools) return;
        tools.innerHTML = "";
        const loc = getLocalization();

        let cancel_button = this._btn("cancel", loc["button_cancel"] || "Back", () => { this.close(); this.commitHandler(image); });
        cancel_button.classList.add("primary");
        tools.append(cancel_button);
        
        if (image.public == 1 || image.public === "1") {
            let assign_btn =             this._btn("assign", loc["label_assign_to_" + this.target] || "Assign", () => { this.close(); this.commitHandler(image); });
            assign_btn.classList.add("primary");
            tools.append(assign_btn,
                this._btn("private", loc.button_depublish, () => this.togglePublish(image, 0))
            );
        } else if (image.licence?.trim().length > 0) {
            let publish_button = this._btn("public", loc.button_publish, () => this.togglePublish(image, 1));
            publish_button.classList.add("primary");
            tools.append(publish_button);
        }

        if (this.permissions.create_image && !this.isUploadMode) {
            tools.append(this._btn("upload", loc.button_upload || "Upload New Image", () => this.prepareUpload(), "width-full"));
        }

        if (this.permissions.delete_image_others) {
            let btn = this._btn("delete", loc.button_delete || "Delete", () => {
                if (confirm("Delete this image?")) this.deleteImage(image.filename);
            });
            btn.classList.add('delete');
            tools.append(btn);
        }
    }

    getField(id) { return this.container.querySelector("#" + id) || this.container.querySelector("[name='" + id + "']"); }

    setFormData(image) {
        const fields = ["name", "description", "licence", "filename"];
        fields.forEach(id => { if (this.getField(id)) this.getField(id).value = image[id] || ""; });
        if (this.getField("public")) this.getField("public").checked = (image.public == 1 || image.public === "1");
    }

    getFormData() {
        const f = (id) => this.getField(id);
        return {
            project_id: this.projectId, studio_id: this.studioId,
            name: f("name")?.value || "", description: f("description")?.value || "",
            licence: f("licence")?.value || "", public: f("public")?.checked ? 1 : 0,
            filename: f("filename")?.value || ""
        };
    }

    async togglePublish(image, status) {
        const data = this.getFormData();
        data.public = status;
        await this.saveImage(data);
    }

    async saveImage(image) {
        image.action = "save";
        const res = await postJson("image.cgi", image);
        if (res) {
            if (typeof showInfo === "function") showInfo(getLocalization().label_saved);
            await this.loadImageEditor(image.filename);
        }
    }

    async deleteImage(filename) {
        await getJson("image.cgi", { action: "delete", project_id: this.projectId, studio_id: this.studioId, filename: filename });
        await this.loadData(this.currentSearchQuery);
    }
}

window.ImageManager = new ImageManager();

function registerImageHandler() {
    document.querySelectorAll("button.select-image").forEach((btn) => {
        if (btn.dataset.hasImageHandler) return;
        btn.dataset.hasImageHandler = "true";
        btn.addEventListener("click", () => {
            window.ImageManager.open(btn.dataset, (image) => {
                const parent = btn.closest("div");
                const hiddenInput = parent.querySelector("input.image");
                const previewImg = parent.querySelector("#imagePreview");
                if (hiddenInput) hiddenInput.value = image.filename;
                if (previewImg) previewImg.src = `show-image.cgi?project_id=${image.project_id}&studio_id=${image.studio_id}&filename=${image.filename}&type=icon`;
                btn.dataset.filename = image.filename;
            });
        });
    });
}

window.calcms = window.calcms || {};
window.calcms.init_image = async function(el) { await loadLocalization("image"); registerImageHandler(); };