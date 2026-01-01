if (window.namespace_image_js) throw "stop"; window.namespace_image_js = true; "use strict";

class ImageManager { constructor() { this.commitHandler = null; this.target = null; this.permissions = {}; this.container = null; this.projectId = null; this.studioId = null; this.isLoading = false; this.initialFilename = null; }

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

    // Main Event Delegation
    this.container.addEventListener("click", (e) => {
        if (e.target.id === 'abort-image-editor' || e.target.closest('#abort-image-editor')) {
            this.close();
        }
        if (e.target.id === 'search-button' || e.target.closest('#search-button')) {
            this.handleSearch();
        }
        // This now catches the button with ID 'upload-button'
        if (e.target.id === 'upload-button' || e.target.closest('#upload-button')) {
            this.showUploadPanel();
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
        group.className = 'tool-group';
        if (warnText) {
            const label = document.createElement('span');
            label.className = 'tool-warning';
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
        const uploadBtn = this.createBtn('upload', loc.button_upload || 'Upload', () => this.showUploadPanel());
        uploadBtn.id = 'upload-button'; // Crucial for delegation
        tools.appendChild(createToolGroup('', uploadBtn));
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

showUploadPanel() {
    const loc = getLocalization();
    const panel = document.createElement('div');
    panel.id = 'upload-panel';
    panel.className = 'panel'; 
    
    // Inline styles to ensure visibility if CSS isn't loaded
    Object.assign(panel.style, {
        position: 'fixed', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
        background: 'white', border: '1px solid #ccc', padding: '20px', zIndex: '2000',
        boxShadow: '0 0 10px rgba(0,0,0,0.5)', minWidth: '300px'
    });

    panel.innerHTML = `
        <div class="panel-content" style="display:flex; flex-direction:column; gap:10px;">
            <h3 style="margin-top:0;">${loc.button_upload || 'Upload New Image'}</h3>
            <div><label style="display:block;">File:</label> <input type="file" id="up-file" accept="image/*"></div>
            <div><label style="display:block;">License:</label> <input type="text" id="up-licence" style="width:100%;"></div>
            <div><label style="display:block;">Description:</label> <textarea id="up-desc" style="width:100%;" rows="3"></textarea></div>
            <div class="actions" style="display:flex; justify-content:flex-end; gap:10px; margin-top:10px;">
                <button id="up-submit" style="font-weight:bold;">${loc.button_upload || 'Upload'}</button>
                <button id="up-cancel">${loc.button_cancel || 'Cancel'}</button>
            </div>
        </div>
    `;

    this.container.appendChild(panel);

    panel.querySelector('#up-cancel').onclick = () => panel.remove();
    panel.querySelector('#up-submit').onclick = async () => {
        const fileInput = panel.querySelector('#up-file');
        const file = fileInput.files[0];
        const licence = panel.querySelector('#up-licence').value;
        const description = panel.querySelector('#up-desc').value;

        if (!file) {
            alert("Please select a file first.");
            return;
        }

        panel.style.opacity = "0.5";
        panel.style.pointerEvents = "none";
        
        await this.handleUpload({ file, licence, description });
        panel.remove();
    };
}

async handleUpload({ file, licence, description }) {
    const fd = new FormData();
    fd.append('action', "upload");
    fd.append('project_id', this.projectId);
    fd.append('studio_id', this.studioId);
    fd.append('upload', file.name);
    fd.append('licence', licence || "");
    fd.append('description', description || "");
    fd.append('image', file);

    try {
        const res = await fetch('image-upload.cgi', { method: 'POST', body: fd });
        if (res.ok) {
            const result = await res.json();
            // Set this as the initial filename so handleSearch sorts it to the top
            this.initialFilename = result.filename || file.name;
            //await this.handleSearch();
        } else {
            console.error("Upload failed");
        }
    } catch (e) {
        console.error("Error during upload:", e);
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
    
    const images = json.images || [];
    // Sort specifically so the newly uploaded file is the first array element
    if (this.initialFilename) {
        images.sort((a, b) => (a.filename === this.initialFilename ? -1 : b.filename === this.initialFilename ? 1 : 0));
    }
    
    this.renderImageList(images);
}

createBtn(spriteName, text, cb) {
    const b = document.createElement('button');
    b.type = 'button';
    b.innerHTML = `<sprite-icon name="${spriteName}"></sprite-icon> ${text}`;
    b.onclick = (e) => { e.preventDefault(); cb(); };
    return b;
}

}

window.ImageManager = new ImageManager();

function registerImageHandler() { document.querySelectorAll("button.select-image").forEach((btn) => { if (btn.dataset.hasImageHandler) return; btn.dataset.hasImageHandler = "true";

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

window.calcms ??= {}; window.calcms.init_image = async function(el) { await loadLocalization('image'); registerImageHandler(); };