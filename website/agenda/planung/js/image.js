"use strict";

function getParent() {
    return document.querySelector("body > #content");
}

function closeImageManager() {
    getParent().style.display = 'flex';
    $('#image-manager').hide(1000).remove();
}

var commitImageHandler;
var target;
var permissions;

// open image editor, pid used for projects
async function selectImage(image, callback) {
    commitImageHandler = callback;
    target = image.target;
    
    let project_id = image.project_id;
    let studio_id = image.studio_id;

    getParent().style.display = "none";
    $('body').append($('<div id="image-manager">'));
    $("#image-manager").on("click", "#abort-image-editor", closeImageManager);

    $("#image-manager").on("click", "#search-button",
        () => searchImage(project_id, studio_id, $("input#search-field").val())
    );
    
    permissions = getJson('permissions.cgi', {
        "project_id" : project_id,
        "studio_id" : studio_id
    });

    let [manager, file_images, series_images, search_images] = await Promise.all([
        updateContainer('image-manager', 'image.cgi?' + new URLSearchParams({
            "action": 'show',
            "project_id": project_id,
            "studio_id": studio_id
        }).toString()),
        image.filename ? getJson('image.cgi', {
            "action": 'get',
            "project_id": project_id,
            "studio_id": studio_id,
            "filename": image.filename
        }) : Promise.resolve([]),
        image.series_id ? getJson('image.cgi', {
            "action": 'get',
            "project_id": project_id,
            "studio_id": studio_id,
            "series_id": image.series_id
        }) : Promise.resolve([]),

        image.search ? getJson('image.cgi', {
            "action": 'get',
            "project_id": project_id,
            "studio_id": studio_id,
            "search": image.search
        }) : Promise.resolve([])
    ]);

    let images = Array.from(new Map([
        ...file_images.images.map(img => [img.filename, img]),
        ...series_images.images.map(img => [img.filename, img]),
        ...search_images.images.map(img => [img.filename, img]),
    ]).values());
    listImages(project_id, studio_id, images);
    return false;
}

function listImages(project_id, studio_id, images) {

    let container = document.querySelector("#image-manager div.images");
    container.innerHTML = '';;
    console.log("container", container)
    if (!container) throw new Error("nos container");

    for (let image of images) {
        let div = document.createElement("div");
        for (let [key, value] of Object.entries(image)) {
            div.dataset[key] = value;
        }
        div.className = "image";
        div.id = `img_${image.id}`;
        div.title = image.description || "";
        let url = `show-image.cgi?` + new URLSearchParams({
            project_id: image.project_id,
            studio_id: image.studio_id,
            type: "icon",
            filename: image.filename
        }).toString();
        div.style.backgroundImage = `url('${url}')`;
        
        div.addEventListener('click', function() {
            loadImageEditor(project_id, studio_id, div.dataset.filename);
        });
        container.append(div);
    }
    loadImageEditor(images[0].project_id, images[0].studio_id, images[0].filename);
    setActiveImage(document.querySelector("div.images div.image"));
    console.log("images initialized")

    return;
}

function setActiveImage(elem) {
    document.querySelectorAll("div.image").forEach(image => {
        image.classList.remove("active");
        image.classList.add("inactive");
    });
    if (!elem) return;
    elem.classList.add("active");
    elem.classList.remove("inactive");
    updateActiveImage();
}

function updateActiveImage() {
    $('div.images div.image.active').click();
}

function parseImageForm() {
    let image = {};
    let editor = document.querySelector("#image-editor");
    image.project_id = editor.querySelector("#project_id").value;
    image.studio_id = editor.querySelector("#studio_id").value;
    image.name = editor.querySelector("#name").value;
    image.description = editor.querySelector("#description").value;
    image.licence = editor.querySelector("#licence").value;
    image.public = editor.querySelector("#public").value;
    image.filename = editor.querySelector("#filename").value;
    return image;
}

function setImageForm(image){
    let editor = document.querySelector("#image-editor");
    editor.querySelector("#project_id").value = image.project_id || 0;
    editor.querySelector("#studio_id").value = image.studio_id || 0;
    editor.querySelector("#name").value = image.name || '';
    editor.querySelector("#description").value = image.description || '';
    editor.querySelector("#licence").value = image.licence || '';
    console.log(image.licence)
    editor.querySelector("#public").checked = !!image.public;
    editor.querySelector("#filename").value = image.filename || '';
}

// show or edit image properties
async function loadImageEditor(project_id, studio_id, filename) {
    var loc = getLocalization();
    let editor = document.querySelector("#image-editor");
    let json = await getJson('image.cgi', {
        "action": 'get',
        "project_id": project_id,
        "studio_id": studio_id,
        "filename": filename
    });
    console.log("load",json)
    let image = json.images[0];

    setImageForm(image);

    document.querySelector('#image-properties').innerHTML = `
    ${loc.label_created_at} ${image.created_at} ${loc.label_created_by} ${image.created_by}<br>
    ${loc.label_modified_at} ${image.modified_at} ${loc.label_modified_by} ${image.modified_by}<br>
    ${loc.label_link} {{${image.filename}|${image.name}}}<br>
    `;

    let tools = document.querySelector("#image-tools");
    tools.innerHTML = '';

    if (image.public) {
        tools.appendChild(button({
            id: "assignButton",
            text: loc["label_assign_to_" + target],
            onClick: () => {
                closeImageManager();
                commitImageHandler(image)
            }
        }));
        tools.appendChild(button({
            id: "depublishButton",
            text: loc.button_depublish,
            onClick: () => depublishImage()
        }));
    } else {
        tools.appendChild(element("div", {
            className: "warn",
            textContent: loc['label_warn_not_public_' + target]
        }));

        if (image.licence) {
            tools.appendChild(button({
                id: "publishButton",
                text: loc.button_publish,
                onClick: () => publishImage()
            }));
        } else {
            tools.appendChild(element("div", {
                className: "warn",
                textContent: loc.label_warn_unknown_licence
            }));
        }
    }
    
    if (!editor.querySelector("#save-image.has-handlers")) {
        editor.querySelector("#save-image").classList.add("has-handlers");
        editor.querySelector("#save-image").addEventListener(
            "click", () => saveImage(parseImageForm()));
    }
    if (!editor.querySelector("#delete-image.has-handlers")) {
        editor.querySelector("#delete-image").classList.add("has-handlers");
        editor.querySelector("#delete-image").addEventListener(
            "click", () => askDeleteImage(parseImageForm().filename));
    }

    if (permissions.create_image) {
        tools.append(
            element("label", {
                textContent: loc.label_file, 
                for: "upload"
            }),
            element("input", {
                type: "file",
                name: "upload",
                accept: "image/*",
                maxlength: "2000000",
                size: "10",
                required: true
            }),
            element("button", {
                textContent: loc.button_upload,
                onClick: () => {uploadImage(); return false;},
            })
        );
    }
    if (permissions.delete_image) {
        tools.appendChild(
            element("button", {
                textContent: loc.delete_upload,
                onClick: () => {deleteImage();return false;},
            })
        )
    }
}

async function searchImage(project_id, studio_id, search) {
    let params = new URLSearchParams({
        action: "get",
        project_id,
        studio_id,
        search
    });
    console.log(search, params);
    let json = await getJson('image.cgi', params);
    listImages(project_id, studio_id, json.images);
    return false;
}

async function saveImage(image) {
    image.action = "save";
    console.log("save",image)
    var doc = await postJson('image.cgi?', image);
    showInfo(loc.label_saved);
    console.log(doc)
    loadImageEditor(image.project_id, image.studio_id, image.filename)
}

function depublishImage() {
    let image = parseImageForm();
    image.public = 0;
    saveImage(image);
}

function publishImage() {
    let image = parseImageForm();
    image.public = 1;
    saveImage(image);
}

function askDeleteImage(filename) {
    commitAction("delete image", () => deleteImage(filename));
}

async function deleteImage(filename) {
    var json = await getJson('image.cgi', {
        "action": "delete",
        "project_id": getProjectId(),
        "studio_id": getStudioId(),
        "filename": filename,
    });
    return false;
}

function uploadImage() {
    var form = $("#img_upload");
    var fd = new FormData(form[0]);
    var rq = $.ajax({
        url: 'image-upload.cgi',
        type: 'POST',
        data: fd,
        cache: false,
        contentType: false,
        processData: false
    });

    rq.done(function(data) {
        var image_id = $("#upload_image_id").html();
        var filename = $("#upload_image_filename").html();
        var title = $("#upload_image_title").html();
        //remove existing image from list
        $('#image-list div.images #img_' + image_id).remove();
        var url = icon(getProjectId(), getStudioId(), filename).src;

        var html = '<div';
        html += ' id="img_' + image_id + '"';
        html += ' class="image" ';
        html += ' title="' + title + '" ';
        html += ' style="background-image:url(' + url + ')"';
        html += ' filename="' + filename + '"';
        html += '>';
        html += '    <div class="label">' + title + '</div>';
        html += '</div>';

        //add image to list
        $('#image-list div.images').prepend(html);
        return false;
    });

    rq.fail(function() {
        console.log("Fail")
    });

    return false;
};

$(document).ready(function() {
    function updateCheckBox(selector, value) {
        $(selector).attr('value', value)
        $(selector).prop("checked", value == 1);
    }

    loadLocalization('image');
    var checkbox = $("#img_editor input[name='public']");
    updateCheckBox(checkbox);
    checkbox.change(() => updateCheckBox(checkbox));
    //console.log("image handler initialized");
});
