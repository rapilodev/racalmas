if (window.namespace_image_js) throw "stop"; window.namespace_image_js = true;
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
        
        // This is the "Truth": what the calling app says is the current image
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

        this.container.addEventListener("click", (e) => {
            if (e.target.id === 'abort-image-editor') this.close();
            if (e.target.id === 'search-button') this.handleSearch();
        });

        // 1. Load HTML and Permissions
        const [perms] = await Promise.all([
            getJson('permissions.cgi', { project_id: this.projectId, studio_id: this.studioId }),
            loadHtmlFragment({
                url: 'image.cgi?' + new URLSearchParams({
                    action: 'show',
                    project_id: this.projectId,
                    studio_id: this.studioId
                }).toString(),
                target: '#image-manager'
            })
        ]);

        this.permissions = perms;

        // 2. Fetch Images
        const baseParams = { project_id: this.projectId, studio_id: this.studioId, action: 'get' };
        
        const [fileRes, seriesRes, searchRes] = await Promise.all([
            this.initialFilename ? getJson('image.cgi', { ...baseParams, filename: this.initialFilename }) : Promise.resolve({images:[]}),
            options.series_id ? getJson('image.cgi', { ...baseParams, series_id: options.series_id }) : Promise.resolve({images:[]}),
            options.search ? getJson('image.cgi', { ...baseParams, search: options.search }) : Promise.resolve({images:[]})
        ]);

        // 3. Merge Logic: Priority goes to the actual selected file
        const imageMap = new Map();
        
        // Put general results first
        if (searchRes.images) searchRes.images.forEach(img => imageMap.set(img.filename, img));
        if (seriesRes.images) seriesRes.images.forEach(img => imageMap.set(img.filename, img));
        
        // Put the specific requested file LAST so it overwrites any partial data from searches
        if (fileRes.images) {
            fileRes.images.forEach(img => {
                imageMap.set(img.filename, img);
            });
        }

        this.renderImageList(Array.from(imageMap.values()));
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

            // STRICT MATCH: Does this thumbnail match the current selected image?
            if (this.initialFilename && image.filename === this.initialFilename) {
                targetThumbnail = div;
            }

            listContainer.append(div);
        });

        // Trigger selection of the specific image passed in open()
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
            action: 'get',
            project_id: this.projectId,
            studio_id: this.studioId,
            filename: filename
        });

        if (!data.images || !data.images[0]) return;
        const image = data.images[0];
        const loc = getLocalization();
        
        this.setFormData(image);

        // Update properties
        const props = this.container.querySelector('#image-properties');
        if (props) {
            props.innerHTML = `
                ${loc.label_created_at} ${image.created_at} ${loc.label_created_by} ${image.created_by}<br>
                ${loc.label_modified_at} ${image.modified_at} ${loc.label_modified_by} ${image.modified_by}<br>
                ${loc.label_link} {{${image.filename}|${image.name}}}<br>
            `;
        }

        this.renderTools(image);
        
        const saveBtn = this.container.querySelector("#save-image");
        if (saveBtn) {
            saveBtn.onclick = (e) => {
                e.preventDefault();
                this.saveImage(this.getFormData());
            };
        }
    }

    renderTools(image) {
        const tools = this.container.querySelector("#image-tools");
        if (!tools) return;
        tools.innerHTML = '';

        const loc = getLocalization();
        const isPublic = (image.public == 1 || image.public === "1");
        const hasLicense = !!(image.licence && String(image.licence).trim() !== "");

        if (isPublic) {
            tools.appendChild(this.createBtn(loc["label_assign_to_" + this.target] || `Assign to ${this.target}`, () => {
                this.close();
                this.commitHandler(image);
            }));
            tools.appendChild(this.createBtn(loc.button_depublish, () => this.togglePublish(image, 0)));

            if (!hasLicense) {
                const warn = document.createElement('div');
                warn.className = 'warn';
                warn.textContent = loc.label_warn_unknown_licence || 'Missing license';
                tools.appendChild(warn);
            }
        } else {
            const warnPublic = document.createElement('div');
            warnPublic.className = 'warn';
            warnPublic.textContent = loc['label_warn_not_public_' + this.target] || 'Not public';
            tools.appendChild(warnPublic);

            if (hasLicense) {
                tools.appendChild(this.createBtn(loc.button_publish, () => this.togglePublish(image, 1)));
            } else {
                const warnLicense = document.createElement('div');
                warnLicense.className = 'warn';
                warnLicense.textContent = loc.label_warn_unknown_licence || 'Missing license';
                tools.appendChild(warnLicense);
            }
        }
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
            this.loadImageEditor(image.filename);
        }
    }

    async handleSearch() {
        const query = this.container.querySelector("input#search-field")?.value || "";
        const json = await getJson('image.cgi', {
            action: "get",
            project_id: this.projectId,
            studio_id: this.studioId,
            search: query
        });
        this.renderImageList(json.images);
    }

    createBtn(text, cb) {
        const b = document.createElement('button');
        b.type = 'button';
        b.textContent = text;
        b.onclick = (e) => { e.preventDefault(); cb(); };
        return b;
    }
}

window.ImageEditor = new ImageManager();
function registerImageHandler(){
    document.querySelectorAll("button.select-image").forEach((btn) => {
        console.log("register button")
        btn.addEventListener("click", () => {
            const parent = btn.closest('div');
            const hiddenInput = parent.querySelector("input.image");
            const previewImg = parent.querySelector("#imagePreview");
            
            console.log("open editor with filename:", btn.dataset.filename);
            
            window.ImageEditor.open(btn.dataset, (image) => {
                // 1. Update the hidden input for form submission
                hiddenInput.value = image.filename;
                
                // 2. Update the preview UI
                previewImg.src = `show-image.cgi?project_id=${image.project_id}&studio_id=${image.studio_id}&filename=${image.filename}&type=icon`;
                
                // 3. FIX: Update the dataset so the NEXT time you open the manager, 
                // it knows this new image is the current one.
                btn.dataset.filename = image.filename;
                
                console.log(`Updated field for event: ${btn.dataset.event_id}`);
            });
        });
    });
}

// Global instance window.ImageEditor = new ImageManager();
// init function
window.calcms??={};
window.calcms.init_image = async function(el) {
    console.log("init images")
    await loadLocalization('image');
    //var checkbox = $("#img_editor input[name='public']");
    //updateCheckBox(checkbox);
    //checkbox.change(() => updateCheckBox(checkbox));
    //console.log("image handler initialized");
}
