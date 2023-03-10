local ffi = require('ffi');
local d3d = require('d3d8');
local d3d8dev = d3d.get_device();
local imgui = require('imgui');

-- Require our header files
require('svgrenderer/include/resvg_h');
require('svgrenderer/include/libhxui_h');

-- Returns a path to a file, relative to our addon directory
local function getRelativePath(filename)
    local path = string.format('%s\\%s', addon.path, filename);

    path = (path:gsub('/', '\\'));

    return (path:gsub('\\\\', '\\'));
end

-- Load our DLLs
local resvg = ffi.load(getRelativePath('svgrenderer/bin/resvg'));
local libhxui = ffi.load(getRelativePath('svgrenderer/bin/libhxui'));

local svgrenderer = {
    -- Font file's path relative to our addon directory
    fontPath = 'assets/fonts/roboto.ttf',
    resvgOptions = nil,
    renderedStrings = {},
    renderedDropShadows = {},
    renderedWindowBackgrounds = {},
};

-- Initialize our resvg options and load our font(s)
svgrenderer.initialize = function()
    svgrenderer.resvgOptions = ffi.new('resvg_options*', resvg.resvg_options_create());

    local fontPath = ffi.new('const char*', getRelativePath(svgrenderer.fontPath));

    resvgCheckResponse(resvg.resvg_options_load_font_file(svgrenderer.resvgOptions, fontPath));
end

svgrenderer.renderToTexture = function(svgString, crop, heightOverride)
    -- Initialize our SVG rendering tree
    local tree = ffi.new('resvg_render_tree*');
    local treeBuff = ffi.new('resvg_render_tree*[1]');

    treeBuff[0] = tree;

    local data = ffi.new('const char*', svgString);

    -- Parse our SVG string into the tree
    resvgCheckResponse(resvg.resvg_parse_tree_from_data(data, string.len(svgString), svgrenderer.resvgOptions, treeBuff));

    local size;

    if crop then
        size = ffi.new('resvg_rect[1]');

        resvg.resvg_get_image_bbox(treeBuff[0], size);
    else
        size = ffi.new('resvg_size[1]', resvg.resvg_get_image_size(treeBuff[0]));
    end

    size = size[0];

    local width = math.ceil(size.width);
    local height = math.ceil(size.height);

    if crop then
        width = width + 3;
    end

    if heightOverride then
        height = heightOverride + 6;
    end

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
    
    return {texture=texture, width=width, height=height};
end

-- Keeping this for posterity
-- This is fast, but shitty table comparison ended up being faster
--[[
svgrenderer.encodeArgs = function(args)
    local result = {};

    for key, val in pairs(args) do
        if type(val) == 'table' then
            table.insert(result, svgrenderer.encodeArgs(val));
        elseif type(val) == 'string' then
            table.insert(result, val);
        else
            table.insert(result, tostring(val));
        end
    end

    return table.concat(result);
end
]]--

-- Shitty table comparison, but fast.
-- This could potentially break with a dynamic number of arguments.
svgrenderer.tableEquals = function(table1, table2)
    if #table1 ~= #table2 then
        return false;
    end

    local tableMismatch = false;

    for key, value in pairs(table1) do
        if type(value) == 'table' then
            if not svgrenderer.tableEquals(table2[key], value) then
                tableMismatch = true;
    
                break;
            end
        else
            if table2[key] ~= value then
                tableMismatch = true;
    
                break;
            end
        end
    end

    return not tableMismatch;
end

-- TODO: Make this work properly
svgrenderer.getDropShadowPadding = function(blurRadius)
    return blurRadius * 2;
end

-- TODO: We need to clear this cache at some point, maybe just force it when resize our bars?
svgrenderer.getDropShadowTexture = function(width, height, rounding, offsetX, offsetY, blurRadius, alpha)
    local args = {width, height, rounding, offsetX, offsetY, blurRadius, alpha};

    local dropShadowIndex;
    local dropShadowData;

    for index, data in ipairs(svgrenderer.renderedDropShadows) do
        if svgrenderer.tableEquals(data.args, args) then
            dropShadowIndex = index;
            dropShadowData = data;

            break;
        end
    end

    if not dropShadowData then
        local padding = svgrenderer.getDropShadowPadding(blurRadius);

        local startX = 0 - padding + math.min(offsetX, 0);
        local startY = 0 - padding + math.min(offsetY, 0);

        local viewBox = {
            startX,
            startY,
            math.abs(startX) + width + padding + math.max(offsetX, 0),
            math.abs(startY) + height + padding + math.max(offsetY, 0)
        }

        local svgString = [[
            <svg viewBox="]] .. table.concat(viewBox, ' ') .. [[" xmlns="http://www.w3.org/2000/svg">
                <rect fill="black" width="]] .. width .. [[" height="]] .. height .. [[" rx="]] .. rounding .. [[" filter="drop-shadow(]] .. offsetX ..  ' ' .. offsetY .. ' ' .. blurRadius .. [[ rgba(0, 0, 0, ]] .. alpha .. [[))"/>
            </svg>
        ]]

        table.insert(svgrenderer.renderedDropShadows, {
            textureData=svgrenderer.renderToTexture(svgString),
            args=args
        });

        dropShadowIndex = #svgrenderer.renderedDropShadows;
    end

    return svgrenderer.renderedDropShadows[dropShadowIndex].textureData;
end

svgrenderer.dropShadow = function(startPos, endPos, rounding, offsetX, offsetY, blurRadius, alpha)
    local width = endPos[1] - startPos[1];
    local height = endPos[2] - startPos[2];

    local textureData = svgrenderer.getDropShadowTexture(width, height, rounding, offsetX, offsetY, blurRadius, alpha);

    local texture = tonumber(ffi.cast("uint32_t", textureData.texture));

    local padding = svgrenderer.getDropShadowPadding(blurRadius);

    imgui.GetBackgroundDrawList():AddImage(
        texture,
        {
            startPos[1] - padding + math.min(offsetX, 0),
            startPos[2] - padding + math.min(offsetY, 0),
        },
        {
            endPos[1] + padding + math.max(offsetX, 0),
            endPos[2] + padding + math.max(offsetY, 0)
        },
        {0, 0},
        {1, 1},
        IM_COL32_WHITE
    );
end

-- Must be called at the end of drawing a window, so we can get the proper dimensions.
svgrenderer.dropShadowCurrentWindow = function(offsetX, offsetY, blurRadius, alpha)
    local startPosX, startPosY = imgui.GetWindowPos();
    local width, height = imgui.GetWindowSize();

    local rounding = 0;

    return svgrenderer.dropShadow(
        {
            startPosX,
            startPosY
        },
        {
            startPosX + width,
            startPosY + height
        },
        rounding,
        offsetX,
        offsetY,
        blurRadius,
        alpha
    )
end

local windowBackground;

svgrenderer.windowBackground = function()
    local windowPosX, windowPosY = imgui.GetWindowPos();
    local windowWidth, windowHeight = imgui.GetWindowSize();

    if not windowBackground then
        local svgString = [[
            <svg width="]] .. windowWidth .. [[" height="]] .. windowHeight .. [[" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <radialGradient id="bgGradient">
                        <stop offset="25%" stop-color="#061d3a" />
                        <stop offset="75%" stop-color="#01112a" />
                    </radialGradient>
                </defs>
                <rect fill="url(#bgGradient)" width="]] .. windowWidth .. [[" height="]] .. windowHeight .. [[" rx="15"/>
            </svg>
        ]]

        windowBackground = svgrenderer.renderToTexture(svgString);
    end

    local windowTexture = tonumber(ffi.cast("uint32_t", windowBackground.texture));

    imgui.GetBackgroundDrawList():AddImage(
        windowTexture,
        {
            windowPosX,
            windowPosY
        },
        {
            windowPosX + windowWidth,
            windowPosY + windowHeight
        },
        {0, 0},
        {1, 1},
        IM_COL32_WHITE
    );
end

svgrenderer.htmlEscape = function(text)
    return string.gsub(text, '%g', {
        ['<'] = '&lt;',
        ['>'] = '&gt;',
        ['&'] = '&amp;'
    });
end

svgrenderer.getTextTexture = function(cacheKey, args)
    if svgrenderer.renderedStrings[cacheKey] == nil or (not args.static and not svgrenderer.tableEquals(svgrenderer.renderedStrings[cacheKey].args, args)) then
        local gradientString = '';
        local fillString;

        if type(args.color) == 'string' then
            fillString = args.color;
        elseif type(args.color) == 'table' then
            gradientString = [[
                <defs>
                    <linearGradient id="gradientFill" gradientTransform="rotate(90)">
                        <stop offset="0%" stop-color="]] .. args.color[1] .. [[" />
                        <stop offset="100%" stop-color="]] .. args.color[2] .. [[" />
                    </linearGradient>
                </defs>
            ]]

            fillString = 'url(#gradientFill)';
        else
            error("Invalid type for text color.  Expected string or table.");
        end

        -- Escape our text, otherwise we'll crash on a special door in Upper Jeuno
        local text = svgrenderer.htmlEscape(args.text);
        
        local svgString = [[
        <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg">
            ]] .. gradientString .. [[
            <text id="text1" x="3" y="3" dominant-baseline="hanging" font-family="'Roboto', sans-serif" font-size="]] .. args.size .. [[" fill="]] .. fillString .. [[" filter="drop-shadow(0 1 2 rgba(0, 0, 0, 0.4))" stroke="#01112A" stroke-width="3px" paint-order="stroke">
                ]] .. text .. [[
            </text>
        </svg>
        ]]

        svgrenderer.renderedStrings[cacheKey] = {
            textureData=svgrenderer.renderToTexture(svgString, true, args.size),
            args=args
        };
    end

    return svgrenderer.renderedStrings[cacheKey].textureData;
end

svgrenderer.text = function(cacheKey, args)
    local textureData = svgrenderer.getTextTexture(cacheKey, args);

    local marginX = args.marginX and args.marginX or 0;

    if args.justify == 'right' then
        local contentWidthX, contentWidthY = imgui.GetWindowContentRegionMax();

        if imgui.GetColumnsCount() > 1 then
            contentWidthX = imgui.GetColumnOffset() + imgui.GetColumnWidth();
        end

        imgui.SetCursorPosX(contentWidthX - textureData.width - marginX);
    else
        imgui.SetCursorPosX(imgui.GetCursorPosX() + marginX);
    end

    local texture = tonumber(ffi.cast("uint32_t", textureData.texture));

    if args.layer == nil then
        imgui.Image(texture, {textureData.width, textureData.height});
    elseif args.layer == 'foreground' then
        local cursorX, cursorY = imgui.GetCursorScreenPos();

        imgui.Dummy({textureData.width, textureData.height});

        imgui.GetForegroundDrawList():AddImage(
            texture,
            {
                cursorX,
                cursorY
            },
            {
                cursorX + textureData.width,
                cursorY + textureData.height
            },
            {0, 0},
            {1, 1},
            IM_COL32_WHITE
        );
    end

    return textureData.width, textureData.height;
end

svgrenderer.initialize();

return svgrenderer;