(function () {
  let payload = window.__PAYLOAD || {};
  const interactive = Boolean(window.__INTERACTIVE);

  const state = {
    annotations: Array.isArray(payload.annotations) ? payload.annotations.slice() : [],
    tool: null,
    selectedId: null,
    annotationColor: payload.annotationColor || "#ff3b30",
    shapeKind: payload.shapeKind || "rectangle",
    nextZ: 1,
    drag: null,
    create: null,
  };

  let stageMetrics = {
    width: payload.stageWidth || 1200,
    height: payload.stageHeight || 800,
    zoom: payload.zoom || 1,
  };

  let stage;
  let overlay;
  let documentEventsBound = false;

  function postNative(message) {
    if (!window.webkit?.messageHandlers?.canvas) {
      return;
    }
    window.webkit.messageHandlers.canvas.postMessage(message);
  }

  function boot() {
    state.nextZ = maxZ() + 1;
    mountStage();
    postNative({
      type: "bootComplete",
      width: stageMetrics.width,
      height: stageMetrics.height,
    });
  }

  function mountStage() {
    document.body.innerHTML = buildStage();
    stage = document.getElementById("stage");
    overlay = document.getElementById("overlay");
    if (!stage || !overlay) {
      throw new Error("Stage markup did not initialize.");
    }
    bindLaunchActions();
    bindDocumentEvents();
    renderAnnotations();
  }

  function updateMountedStage() {
    const viewport = document.getElementById("viewport");
    const stageShell = document.getElementById("stage-shell");
    const stageWrap = document.getElementById("stage-wrap");
    const card = document.getElementById("card");
    const image = card?.querySelector("img");

    if (!viewport || !stageShell || !stageWrap || !stage || !overlay || !card || !image) {
      mountStage();
      return;
    }

    stageShell.style.width = `${stageMetrics.width * stageMetrics.zoom}px`;
    stageShell.style.height = `${stageMetrics.height * stageMetrics.zoom}px`;

    stageWrap.style.transform = `scale(${stageMetrics.zoom})`;
    stageWrap.style.width = `${stageMetrics.width}px`;
    stageWrap.style.height = `${stageMetrics.height}px`;

    stage.style.width = `${stageMetrics.width}px`;
    stage.style.height = `${stageMetrics.height}px`;
    applyStageBackground();

    card.style.setProperty("--card-radius", `${payload.cornerRadius}px`);
    card.style.left = `${payload.cardX}px`;
    card.style.top = `${payload.cardY}px`;
    card.style.width = `${payload.imageWidth}px`;
    card.style.height = `${payload.imageHeight}px`;
    card.style.boxShadow = `0 24px ${Math.max(payload.shadow, 8)}px rgba(0,0,0,0.28)`;
    card.style.transform = `perspective(1400px) rotateX(${payload.tiltX}deg) rotateY(${payload.tiltY}deg)`;

    if (image.getAttribute("src") !== payload.sourceImageURL) {
      image.setAttribute("src", payload.sourceImageURL);
    }

    syncWatermark();
    renderAnnotations();
  }

  function buildStage() {
    if (payload.isPlaceholder) {
      return `
        <div id="viewport" class="empty-viewport">
          <div id="stage-shell" style="width:${stageMetrics.width}px;height:${stageMetrics.height}px;">
            <div id="stage-wrap" style="width:${stageMetrics.width}px;height:${stageMetrics.height}px;">
              <div id="stage" class="placeholder-stage" style="--stage-radius:${payload.stageCornerRadius}px;width:${stageMetrics.width}px;height:${stageMetrics.height}px;">
                <div id="background-layer" class="placeholder-background"></div>
                <div id="card" class="placeholder-card" style="left:${payload.cardX}px;top:${payload.cardY}px;width:${payload.imageWidth}px;height:${payload.imageHeight}px;border-radius:${payload.cornerRadius}px;">
                  <div class="placeholder-glyph"></div>
                  <h1>Make it shareable fast</h1>
                  <p>Capture a screenshot, or bring in an image you already have.</p>
                  <div class="placeholder-actions">
                    <button class="launch-button primary" data-native-action="capture">Capture Screenshot</button>
                    <div class="secondary-actions">
                      <button class="launch-button secondary" data-native-action="paste">Paste From Clipboard</button>
                      <button class="launch-button secondary" data-native-action="open">Open Image</button>
                    </div>
                  </div>
                  <div class="shortcut-hints">
                    <span>${escapeHTML(payload.captureShortcutDisplay)} captures</span>
                    <span>${escapeHTML(payload.captureAndCopyShortcutDisplay)} captures and copies styled</span>
                  </div>
                </div>
                <div id="overlay"></div>
              </div>
            </div>
          </div>
        </div>
      `;
    }

    return `
      <div id="viewport">
        <div id="stage-shell" style="width:${stageMetrics.width * stageMetrics.zoom}px;height:${stageMetrics.height * stageMetrics.zoom}px;">
          <div id="stage-wrap" style="transform:scale(${stageMetrics.zoom});width:${stageMetrics.width}px;height:${stageMetrics.height}px;">
            <div id="stage" style="--stage-radius:${payload.stageCornerRadius}px;width:${stageMetrics.width}px;height:${stageMetrics.height}px;${backgroundStyle()}">
              <div id="background-layer"></div>
              <div
                id="card"
                style="
                  --card-radius:${payload.cornerRadius}px;
                  left:${payload.cardX}px;
                  top:${payload.cardY}px;
                  width:${payload.imageWidth}px;
                  height:${payload.imageHeight}px;
                  box-shadow: 0 24px ${Math.max(payload.shadow, 8)}px rgba(0,0,0,0.28);
                  transform: perspective(1400px) rotateX(${payload.tiltX}deg) rotateY(${payload.tiltY}deg);
                "
              >
                <img src="${payload.sourceImageURL}" draggable="false" alt="" />
              </div>
              ${payload.watermarkEnabled ? `<div id="watermark">${escapeHTML(payload.watermarkText || "")}</div>` : ""}
              <div id="overlay"></div>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  function backgroundStyle() {
    if (payload.backgroundMode === "none") {
      return "background: transparent;";
    }
    if (payload.backgroundMode === "solid") {
      return `background:${payload.solidColor};`;
    }
    if (payload.backgroundMode === "gradient") {
      return `background:linear-gradient(135deg, ${payload.gradientStart}, ${payload.gradientEnd});`;
    }
    if (payload.backgroundMode === "customImage" && payload.customBackgroundURL) {
      return `background-image:url('${payload.customBackgroundURL}');background-size:cover;background-position:center;`;
    }
    return `background:linear-gradient(135deg, ${payload.presetStart}, ${payload.presetEnd});`;
  }

  function applyStageBackground() {
    stage?.setAttribute(
      "style",
      `--stage-radius:${payload.stageCornerRadius}px;width:${stageMetrics.width}px;height:${stageMetrics.height}px;${backgroundStyle()}`
    );
  }

  function renderAnnotations() {
    overlay.innerHTML = "";

    for (const annotation of state.annotations) {
      const element = document.createElement("div");
      element.className = annotationClass(annotation);
      element.dataset.id = annotation.id;
      element.style.left = `${annotation.x}px`;
      element.style.top = `${annotation.y}px`;
      element.style.width = `${Math.max(annotation.width, 4)}px`;
      element.style.height = `${Math.max(annotation.height, 4)}px`;
      element.style.zIndex = String(annotation.zIndex || 1);
      element.style.color = annotation.colorHex || "#ff3b30";

      if (annotation.kind === "arrow" || (annotation.kind === "shape" && annotation.shapeKind === "line")) {
        element.style.transform = `rotate(${annotation.rotation || 0}deg)`;
      }

      if (annotation.kind === "text") {
        element.textContent = annotation.text || "Text";
        element.addEventListener("dblclick", () => beginTextEdit(element, annotation.id));
      }

      if (annotation.id === state.selectedId) {
        element.classList.add("selected");
      }

      element.addEventListener("mousedown", (event) => {
        if (!interactive) {
          return;
        }
        if (element.getAttribute("contenteditable") === "true") {
          return;
        }
        event.preventDefault();
        event.stopPropagation();
        select(annotation.id);
        state.drag = {
          id: annotation.id,
          start: stagePoint(event),
          originX: annotation.x,
          originY: annotation.y,
        };
      });

      overlay.appendChild(element);
    }
  }

  function annotationClass(annotation) {
    if (annotation.kind === "shape") {
      return `annotation shape ${annotation.shapeKind || "rectangle"}`;
    }
    return `annotation ${annotation.kind}`;
  }

  function bindDocumentEvents() {
    if (!interactive) {
      return;
    }

    stage.addEventListener("mousedown", handleStageMouseDown);
    if (documentEventsBound) {
      return;
    }
    document.addEventListener("mousemove", handleMouseMove);
    document.addEventListener("mouseup", handleMouseUp);
    document.addEventListener("keydown", handleKeyDown);
    documentEventsBound = true;
  }

  function bindLaunchActions() {
    document.querySelectorAll("[data-native-action]").forEach((button) => {
      button.addEventListener("click", () => {
        postNative({
          type: "launchAction",
          action: button.dataset.nativeAction,
        });
      });
    });
  }

  function syncWatermark() {
    const existingWatermark = document.getElementById("watermark");

    if (!payload.watermarkEnabled) {
      existingWatermark?.remove();
      return;
    }

    if (existingWatermark) {
      existingWatermark.textContent = payload.watermarkText || "";
      return;
    }

    const watermark = document.createElement("div");
    watermark.id = "watermark";
    watermark.textContent = payload.watermarkText || "";
    stage.appendChild(watermark);
  }

  function handleStageMouseDown(event) {
    if (event.target !== stage && event.target !== overlay) {
      return;
    }

    if (!state.tool) {
      select(null);
      return;
    }

    const point = stagePoint(event);

    if (state.tool === "text") {
      const annotation = {
        id: crypto.randomUUID(),
        kind: "text",
        x: point.x,
        y: point.y,
        width: 160,
        height: 42,
        rotation: 0,
        zIndex: state.nextZ++,
        colorHex: state.annotationColor,
        text: "Text",
        shapeKind: null,
      };
      state.annotations.push(annotation);
      select(annotation.id);
      renderAnnotations();
      syncAnnotations();
      requestAnimationFrame(() => {
        const el = overlay.querySelector(`[data-id="${annotation.id}"]`);
        if (el) {
          beginTextEdit(el, annotation.id);
        }
      });
      return;
    }

    state.create = {
      start: point,
      current: point,
    };
    select(null);
  }

  function handleMouseMove(event) {
    if (state.drag) {
      const point = stagePoint(event);
      const annotation = findAnnotation(state.drag.id);
      if (!annotation) {
        return;
      }
      annotation.x = Math.round(state.drag.originX + (point.x - state.drag.start.x));
      annotation.y = Math.round(state.drag.originY + (point.y - state.drag.start.y));
      renderAnnotations();
      syncAnnotations();
      return;
    }

    if (!state.create) {
      return;
    }

    state.create.current = stagePoint(event);
    renderPreviewAnnotation();
  }

  function handleMouseUp() {
    if (state.drag) {
      state.drag = null;
      return;
    }

    if (!state.create) {
      return;
    }

    const annotation = finalizeCreation();
    state.create = null;
    removePreview();

    if (annotation) {
      state.annotations.push(annotation);
      select(annotation.id);
      syncAnnotations();
    }
    renderAnnotations();
  }

  function handleKeyDown(event) {
    if ((event.key === "Delete" || event.key === "Backspace") && state.selectedId) {
      const index = state.annotations.findIndex((item) => item.id === state.selectedId);
      if (index >= 0) {
        state.annotations.splice(index, 1);
        state.selectedId = null;
        renderAnnotations();
        syncAnnotations();
      }
    }

    if (event.key === "Escape") {
      state.tool = null;
      state.selectedId = null;
      state.drag = null;
      state.create = null;
      removePreview();
      renderAnnotations();
    }
  }

  function renderPreviewAnnotation() {
    removePreview();
    const annotation = makeAnnotationFromPoints(state.create.start, state.create.current);
    if (!annotation) {
      return;
    }
    const preview = document.createElement("div");
    preview.id = "preview-annotation";
    preview.className = annotationClass(annotation);
    preview.style.opacity = "0.65";
    preview.style.left = `${annotation.x}px`;
    preview.style.top = `${annotation.y}px`;
    preview.style.width = `${Math.max(annotation.width, 4)}px`;
    preview.style.height = `${Math.max(annotation.height, 4)}px`;
    preview.style.color = annotation.colorHex;
    preview.style.zIndex = String(state.nextZ + 1000);
    if (annotation.kind === "arrow" || annotation.shapeKind === "line") {
      preview.style.transform = `rotate(${annotation.rotation || 0}deg)`;
    }
    overlay.appendChild(preview);
  }

  function finalizeCreation() {
    const annotation = makeAnnotationFromPoints(state.create.start, state.create.current);
    if (!annotation) {
      return null;
    }
    annotation.id = crypto.randomUUID();
    annotation.zIndex = state.nextZ++;
    return annotation;
  }

  function makeAnnotationFromPoints(start, end) {
    const dx = end.x - start.x;
    const dy = end.y - start.y;
    const width = Math.abs(dx);
    const height = Math.abs(dy);

    if (state.tool === "redact") {
      if (width < 8 || height < 8) {
        return null;
      }
      return {
        id: "",
        kind: "redact",
        x: Math.min(start.x, end.x),
        y: Math.min(start.y, end.y),
        width,
        height,
        rotation: 0,
        zIndex: 0,
        colorHex: "#000000",
        text: null,
        shapeKind: null,
      };
    }

    if (state.tool === "shape") {
      if (state.shapeKind === "line") {
        const rotation = Math.atan2(dy, dx) * 180 / Math.PI;
        return {
          id: "",
          kind: "shape",
          x: start.x,
          y: start.y,
          width: Math.max(Math.sqrt((dx * dx) + (dy * dy)), 20),
          height: 0,
          rotation,
          zIndex: 0,
          colorHex: state.annotationColor,
          text: null,
          shapeKind: "line",
        };
      }

      if (width < 10 || height < 10) {
        return null;
      }
      return {
        id: "",
        kind: "shape",
        x: Math.min(start.x, end.x),
        y: Math.min(start.y, end.y),
        width,
        height,
        rotation: 0,
        zIndex: 0,
        colorHex: state.annotationColor,
        text: null,
        shapeKind: state.shapeKind,
      };
    }

    if (state.tool === "arrow") {
      const length = Math.max(Math.sqrt((dx * dx) + (dy * dy)), 26);
      const rotation = Math.atan2(dy, dx) * 180 / Math.PI;
      return {
        id: "",
        kind: "arrow",
        x: start.x,
        y: start.y,
        width: length,
        height: 6,
        rotation,
        zIndex: 0,
        colorHex: state.annotationColor,
        text: null,
        shapeKind: null,
      };
    }

    return null;
  }

  function beginTextEdit(element, id) {
    const annotation = findAnnotation(id);
    if (!annotation) {
      return;
    }
    element.setAttribute("contenteditable", "true");
    element.focus();
    selectText(element);
    element.addEventListener("blur", () => {
      annotation.text = element.textContent || "Text";
      element.removeAttribute("contenteditable");
      renderAnnotations();
      syncAnnotations();
    }, { once: true });
  }

  function stagePoint(event) {
    const rect = stage.getBoundingClientRect();
    return {
      x: Math.round((event.clientX - rect.left) / stageMetrics.zoom),
      y: Math.round((event.clientY - rect.top) / stageMetrics.zoom),
    };
  }

  function findAnnotation(id) {
    return state.annotations.find((item) => item.id === id);
  }

  function select(id) {
    state.selectedId = id;
    renderAnnotations();
  }

  function removePreview() {
    const preview = document.getElementById("preview-annotation");
    if (preview) {
      preview.remove();
    }
  }

  function maxZ() {
    return state.annotations.reduce((max, item) => Math.max(max, item.zIndex || 1), 1);
  }

  function syncAnnotations() {
    if (!interactive) {
      return;
    }
    postNative({
      type: "annotationsChanged",
      annotations: state.annotations,
    });
  }

  function escapeHTML(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function selectText(element) {
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(element);
    selection.removeAllRanges();
    selection.addRange(range);
  }

  window.activateTool = function (tool) {
    state.tool = tool || null;
  };

  window.updateEditorConfig = function (config) {
    if (!config) {
      return;
    }
    state.annotationColor = config.annotationColor || state.annotationColor;
    state.shapeKind = config.shapeKind || state.shapeKind;
  };

  window.updatePayload = function (nextPayload) {
    if (!nextPayload) {
      return;
    }
    const needsRemount = Boolean(payload.isPlaceholder) || Boolean(nextPayload.isPlaceholder);
    payload = nextPayload;
    stageMetrics = {
      width: payload.stageWidth || 1200,
      height: payload.stageHeight || 800,
      zoom: payload.zoom || 1,
    };
    state.annotations = Array.isArray(payload.annotations) ? payload.annotations.slice() : [];
    state.annotationColor = payload.annotationColor || state.annotationColor;
    state.shapeKind = payload.shapeKind || state.shapeKind;
    state.nextZ = maxZ() + 1;
    state.selectedId = state.annotations.some((item) => item.id === state.selectedId) ? state.selectedId : null;
    if (needsRemount) {
      mountStage();
      return;
    }
    updateMountedStage();
  };

  try {
    boot();
  } catch (error) {
    postNative({
      type: "bootError",
      message: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
})();
