local ffi = require('ffi');
local d3d = require('d3d8');
local d3d8dev = d3d.get_device();
local imgui = require('imgui');

-- Require our header files
require('textrenderer/include/resvg_h');
require('textrenderer/include/libhxui_h');

-- Returns a path to a file, relative to our addon directory
local function getRelativePath(filename)
    local path = string.format('%s\\%s', addon.path, filename);

    path = (path:gsub('/', '\\'));

    return (path:gsub('\\\\', '\\'));
end

-- Load our DLLs
local resvg = ffi.load(getRelativePath('textrenderer/bin/resvg'));
local libhxui = ffi.load(getRelativePath('textrenderer/bin/libhxui'));

local textrenderer = {
    -- Font file's path relative to our addon directory
    fontPath = 'assets/fonts/roboto.ttf',
    resvgOptions = nil,
    renderedStrings = T{},
    delayedDrawingStack = T{}
};

-- Initialize our resvg options and load our font(s)
textrenderer.initialize = function()
    textrenderer.resvgOptions = ffi.new('resvg_options*', resvg.resvg_options_create());

    local fontPath = ffi.new('const char*', getRelativePath(textrenderer.fontPath));

    resvgCheckResponse(resvg.resvg_options_load_font_file(textrenderer.resvgOptions, fontPath));
end

textrenderer.renderTexture = function(text, size, color, options)
    -- Initialize our SVG rendering tree
    local tree = ffi.new('resvg_render_tree*');
    local treeBuff = ffi.new('resvg_render_tree*[1]');

    treeBuff[0] = tree;

    -- Tweak this to modify the default text style
    local svgString = [[
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg">
        <defs>
            <linearGradient id="gradientFill" gradientTransform="rotate(90)">
                <stop offset="30%" stop-color="#FFFFFF" />
                <stop offset="100%" stop-color="#a2a2a2" />
            </linearGradient>
        </defs>
        <text id="text1" x="3" y="3" dominant-baseline="hanging" font-family="'Roboto', sans-serif" font-size="]] .. size .. [[" fill="url(#gradientFill)" filter="drop-shadow(black 0 1 1)" stroke="black" stroke-width="3px" paint-order="stroke">
            ]] .. text .. [[
        </text>
    </svg>
    ]]

    local data = ffi.new('const char*', svgString);

    -- Parse our SVG string into the tree
    resvgCheckResponse(resvg.resvg_parse_tree_from_data(data, string.len(svgString), textrenderer.resvgOptions, treeBuff));

    -- Get the bounds of our rendered SVG image
    local bbox = ffi.new('resvg_rect[1]');

    resvg.resvg_get_image_bbox(treeBuff[0], bbox);

    bbox = bbox[0];

    local width = math.ceil(bbox.width) + 3;
    -- local height = math.floor(bbox.height) + padding;
    local height = size + 6;

    -- Initialize our DirectX texture
    local texturePointer = ffi.new('IDirect3DTexture8*[1]');

    local response = ffi.C.D3DXCreateTexture(d3d8dev, width, height, ffi.C.D3DX_DEFAULT, ffi.C.D3DUSAGE_DYNAMIC, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_DEFAULT, texturePointer);

    if (response ~= ffi.C.S_OK) then
        error(('Error Creating Texture: %08X (%s)'):fmt(response, d3d.get_error(response)));
    end

    -- Lock our whole texture for drawing
    local lockResponse, lockedRect = texturePointer[0]:LockRect(0, null, ffi.C.D3DLOCK_DISCARD);

    if lockResponse ~= ffi.C.S_OK then
        error(('%08X (%s)'):fmt(lockResponse, d3d.get_error(lockResponse)));
    end

    -- Initialize our texture with 0s
    ffi.fill(lockedRect.pBits, (lockedRect.Pitch / 4) * height * 4);

    -- Determine how resvg should fit our rendered image
    local fitTo = ffi.new('resvg_fit_to[1]');

    fitTo = {resvg.RESVG_FIT_TO_TYPE_ORIGINAL, 1};

    -- Render our tree onto our texture
    resvg.resvg_render(treeBuff[0], fitTo, resvg.resvg_transform_identity(), lockedRect.Pitch / 4, height, lockedRect.pBits);

    -- resvg renders in RGBA, we want BGRA
    libhxui.libhxui_texture_convert_rgba_bgra(lockedRect.pBits, lockedRect.Pitch * height);

    -- Done drawing, unlock our texture
    texturePointer[0]:UnlockRect(0);

    local texture = ffi.new('IDirect3DTexture8*', texturePointer[0]);

    -- Clean up some stuff
    d3d.gc_safe_release(texture);

    resvg.resvg_tree_destroy(treeBuff[0]);
    
    return T{texture=texture, width=width, height=height};
end

textrenderer.getTexture = function(cacheKey, text, size, color, options)
    local args = T{text, size, color, options};

    if not textrenderer.renderedStrings[cacheKey] or not textrenderer.renderedStrings[cacheKey].args:equals(args) then
        textrenderer.renderedStrings[cacheKey] = T{
            textureData=textrenderer.renderTexture(text, size, color, options),
            args=args
        }
    end

    return textrenderer.renderedStrings[cacheKey].textureData;
end

textrenderer.text = function(cacheKey, text, size, color, options)
    if not options then options = {} end;

    local textureData = textrenderer.getTexture(cacheKey, text, size, color, options);

    local marginX = options.marginX and options.marginX or 0;

    if options.justify == 'right' then
        local contentWidthX, contentWidthY = imgui.GetWindowContentRegionMax();

        if imgui.GetColumnsCount() > 1 then
            contentWidthX = imgui.GetColumnOffset() + imgui.GetColumnWidth();
        end

        imgui.SetCursorPosX(contentWidthX - textureData.width - marginX);
    else
        imgui.SetCursorPosX(imgui.GetCursorPosX() + marginX);
    end

    if not options.delayDrawing then
        local texture = tonumber(ffi.cast("uint32_t", textureData.texture));

        imgui.Image(texture, {textureData.width, textureData.height});
    else
        -- Draw a dummy instead for layout purposes, and then draw the actual text
        -- when we call popDelayedDraws()
        local cursorX, cursorY = imgui.GetCursorScreenPos();

        textrenderer.delayedDrawingStack:append(T{
            cacheKey = cacheKey,
            cursor = T{
                x = cursorX,
                y = cursorY
            }
        });

        imgui.Dummy({textureData.width, textureData.height});
    end

    return textureData.width, textureData.height;
end

textrenderer.popDelayedDraws = function(count)
    if count > textrenderer.delayedDrawingStack:length() then
        error("Number of popped delayed draws exceeded stack size.");
    end

    for i = 1, count do
        local stackConfig = table.remove(textrenderer.delayedDrawingStack, i);

        local textureData = textrenderer.renderedStrings[stackConfig.cacheKey].textureData;

        local texture = tonumber(ffi.cast("uint32_t", textureData.texture));

        imgui.GetWindowDrawList():AddImage(
            texture,
            {stackConfig.cursor.x, stackConfig.cursor.y},
            {stackConfig.cursor.x + textureData.width, stackConfig.cursor.y + textureData.height},
            {0, 0},
            {1, 1},
            IM_COL32_WHITE
        );
    end
end

textrenderer.initialize();

return textrenderer;