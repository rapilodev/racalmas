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

    async open(options, callback) {
        if (this.isLoading) return;
        this.isLoading = true;

        this.commitHandler = callback;
        this.target = options.target;
        this.projectId = options.project_id;
        this.studioId = options.studio_id;
        this.initialFilename = options.filename || null;
        
        // Nutzt options.search (aus data-search am Button)
        this.currentSearchQuery = options.search || ""; 
        this.isUploadMode = false;

        const mainContent = document.querySelector("body > #content");
        if (mainContent) mainContent.style.display = "none";

        this.container = document.createElement("div");
        this.container.id = "image-manager";
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
            if (e.target.id === "abort-image-editor" || e.target.closest("#abort-image-editor")) {
                this.close();
            }
            if (e.target.id === "search-button" || e.target.closest("#search-button")) {
                this.handleSearch();
            }
        });

        const urlParams = new URLSearchParams({
            action: "show", 
            project_id: this.projectId, 
            studio_id: this.studioId
        }).toString();

        const [perms] = await Promise.all([
            getJson("permissions.cgi", { project_id: this.projectId, studio_id: this.studioId }),
            loadHtmlFragment({
                url: "image.cgi?" + urlParams,
                target: "#image-manager"
            })
        ]);
        this.permissions = perms;

        const searchInput = this.container.querySelector("input#search-field");
        if (searchInput) searchInput.value = this.currentSearchQuery;

        await this.loadData(this.currentSearchQuery);
    }

    async handleSearch() {
        const searchInput = this.container.querySelector("input#search-field");
        this.currentSearchQuery = searchInput ? searchInput.value.trim() : "";
        await this.loadData(this.currentSearchQuery);
    }

    async loadData(query) {
        const params = { 
            action: "get", 
            project_id: this.projectId, 
            studio_id: this.studioId 
        };
        if (query) params.search = query;
        
        const json = await getJson("image.cgi", params);
        await this.processAndRender(json);
    }

    async processAndRender(json) {
        let images = (json && json.images) ? json.images : [];
        
        if (this.initialFilename) {
            const index = images.findIndex(img => img.filename === this.initialFilename);
            if (index > -1) {
                const currentImg = images.splice(index, 1)[0];
                images.unshift(currentImg);
            } else {
                const singleJson = await getJson("image.cgi", {
                    action: "get",
                    project_id: this.projectId,
                    studio_id: this.studioId,
                    filename: this.initialFilename
                });
                if (singleJson && singleJson.images && singleJson.images[0]) {
                    images.unshift(singleJson.images[0]);
                }
            }
        }
        
        if (this.permissions.create_image) {
            const uploadDummy = { filename: "__NEW__", id: "new", name: "New Upload" };
            images.unshift(uploadDummy);
        }
        
        this.renderImageList(images);
    }

    renderImageList(images) {
        const listContainer = this.container.querySelector("div.images");
        if (!listContainer) return;

        listContainer.innerHTML = "";
        let targetThumbnail = null;

        images.forEach(image => {
            const div = document.createElement("div");
            div.className = "image inactive";
            if (image.filename === "__NEW__") div.classList.add("upload-placeholder");
            
            div.id = "img_" + image.id;
            div.dataset.filename = image.filename;
            
            if (image.filename !== "__NEW__") {
                const url = "show-image.cgi?project_id=" + this.projectId + "&studio_id=" + this.studioId + "&type=icon&filename=" + encodeURIComponent(image.filename);
                div.style.backgroundImage = "url('" + url + "')";
            } else {
                div.innerHTML = "<sprite-icon name='upload' style='margin:auto;'></sprite-icon>";
                div.style.backgroundColor = "#e0e0e0";
                div.style.display = "flex";
            }

            div.onclick = () => {
                this.setActiveThumbnail(div);
                if (image.filename === "__NEW__") {
                    this.prepareUpload();
                } else {
                    this.isUploadMode = false;
                    this.loadImageEditor(image.filename);
                }
            };

            if (this.isUploadMode && image.filename === "__NEW__") {
                targetThumbnail = div;
            } else if (!this.isUploadMode && this.initialFilename && image.filename === this.initialFilename) {
                targetThumbnail = div;
            }
            
            listContainer.append(div);
        });

        if (targetThumbnail) {
            targetThumbnail.click();
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

    prepareUpload() {
        this.isUploadMode = true;
        const loc = getLocalization();
        this.setFormData({ name: "", description: "", licence: "", public: 0 });
        
        const props = this.container.querySelector("#image-properties");
        if (props) {
            props.innerHTML = "<b style='color:var(--brand-color);'>" + (loc.label_new_upload || "New Image Upload") + "</b><br>" +
                               "<span>" + (loc.label_select_file_hint || "Select a file using the button below") + "</span>";
        }

        const tools = this.container.querySelector("#image-tools");
        if (tools) tools.innerHTML = "";

        const saveBtn = this.container.querySelector("#save-image");
        if (saveBtn) {
            saveBtn.innerHTML = "<sprite-icon name='upload'></sprite-icon> " + (loc.button_upload || "Choose File & Upload");
            saveBtn.onclick = (e) => {
                e.preventDefault();
                this.triggerFilePicker();
            };
        }
    }

    triggerFilePicker() {
        let input = document.getElementById("hidden-upload-input");
        if (!input) {
            input = document.createElement("input");
            input.type = "file";
            input.id = "hidden-upload-input";
            input.accept = "image/*";
            input.style.display = "none";
            document.body.appendChild(input);
        }
        input.onchange = (e) => {
            if (e.target.files && e.target.files[0]) {
                this.processUpload(e.target.files[0]);
            }
        };
        input.click();
    }

    async processUpload(file) {
        const data = this.getFormData();
        const fd = new FormData();
        fd.append("action", "upload");
        fd.append("project_id", this.projectId);
        fd.append("studio_id", this.studioId);
        fd.append("upload", file.name);
        fd.append("licence", data.licence);
        fd.append("description", data.description);
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
        const data = await getJson("image.cgi", {
            action: "get", project_id: this.projectId, studio_id: this.studioId, filename: filename
        });

        if (!data || !data.images || !data.images[0]) return;
        const image = data.images[0];

        this.setFormData(image);
        this.renderTools(image);
        this.attachLiveValidation(image);

        const loc = getLocalization();
        const props = this.container.querySelector("#image-properties");
        if (props) {
            props.innerHTML = loc.label_created_at + " " + image.created_at + " " + loc.label_created_by + " " + image.created_by + "<br>" +
                              loc.label_modified_at + " " + image.modified_at + " " + loc.label_modified_by + " " + image.modified_by + "<br>" +
                              loc.label_link + " {{" + image.filename + "|" + image.name + "}}<br>";
        }

        const saveBtn = this.container.querySelector("#save-image");
        if (saveBtn) {
            saveBtn.innerHTML = "<sprite-icon name='save'></sprite-icon> " + (loc.button_save || "Save");
            saveBtn.onclick = (e) => {
                e.preventDefault();
                this.saveImage(this.getFormData());
            };
        }
    }

    attachLiveValidation(image) {
        const licInput = this.getField("licence");
        const pubCheck = this.getField("public");
        if (licInput) {
            licInput.oninput = () => { image.licence = licInput.value; this.renderTools(image); };
        }
        if (pubCheck) {
            pubCheck.onchange = () => { image.public = pubCheck.checked ? 1 : 0; this.renderTools(image); };
        }
    }

    renderTools(image) {
        const tools = this.container.querySelector("#image-tools");
        if (!tools) return;
        tools.innerHTML = "";
        const loc = getLocalization();

        if (image.public == 1 || image.public === "1") {
            tools.appendChild(this.createBtn("assign", (loc["label_assign_to_" + this.target] || "Assign"), () => {
                this.close();
                this.commitHandler(image);
            }));
            tools.appendChild(this.createBtn("private", loc.button_depublish, () => this.togglePublish(image, 0)));
        } else if (image.licence && String(image.licence).trim().length > 0) {
            tools.appendChild(this.createBtn("public", loc.button_publish, () => this.togglePublish(image, 1)));
        }

        if (this.permissions.delete_image) {
            tools.appendChild(this.createBtn("delete", loc.button_delete || "Delete", () => {
                if (confirm("Delete this image?")) this.deleteImage(image.filename);
            }));
        }
    }

    getField(id) { return this.container.querySelector("#" + id) || this.container.querySelector("[name='" + id + "']"); }

    setFormData(image) {
        const f = (id) => this.getField(id);
        if (f("name")) f("name").value = image.name || "";
        if (f("description")) f("description").value = image.description || "";
        if (f("licence")) f("licence").value = image.licence || "";
        if (f("public")) f("public").checked = (image.public == 1 || image.public === "1");
        if (f("filename")) f("filename").value = image.filename || "";
    }

    getFormData() {
        const f = (id) => this.getField(id);
        return {
            project_id: this.projectId,
            studio_id: this.studioId,
            name: f("name") ? f("name").value : "",
            description: f("description") ? f("description").value : "",
            licence: f("licence") ? f("licence").value : "",
            public: (f("public") && f("public").checked) ? 1 : 0,
            filename: f("filename") ? f("filename").value : ""
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

    createBtn(spriteName, text, cb) {
        const b = document.createElement("button");
        b.type = "button";
        b.innerHTML = "<sprite-icon name='" + spriteName + "'></sprite-icon> " + text;
        b.onclick = (e) => { e.preventDefault(); cb(); };
        return b;
    }
}

window.ImageManager = new ImageManager();

function registerImageHandler() {
    document.querySelectorAll("button.select-image").forEach((btn) => {
        if (btn.dataset.hasImageHandler) return;
        btn.dataset.hasImageHandler = "true";
        btn.addEventListener("click", () => {
            // Verwendet btn.dataset direkt (enthält filename, target, project_id, studio_id UND search)
            window.ImageManager.open(btn.dataset, (image) => {
                const parent = btn.closest("div");
                const hiddenInput = parent.querySelector("input.image");
                const previewImg = parent.querySelector("#imagePreview");
                if (hiddenInput) hiddenInput.value = image.filename;
                if (previewImg) previewImg.src = "show-image.cgi?project_id=" + image.project_id + "&studio_id=" + image.studio_id + "&filename=" + image.filename + "&type=icon";
                btn.dataset.filename = image.filename;
            });
        });
    });
}

window.calcms = window.calcms || {};
window.calcms.init_image = async function(el) { await loadLocalization("image"); registerImageHandler(); };