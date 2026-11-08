import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// A page that scrolls like native lists: the focused row is kept in the middle
// of the screen and UP / DOWN glide to the next row (~0.25 s, ease-out).
// While gliding, the page is drawn once into an off-screen bitmap and only
// that bitmap is moved each frame, so even slow watches get a smooth scroll.
// Subclasses draw the content (drawContent) and anything fixed on top
// (drawOverlay), and say where each focus position scrolls to (targetFor).
class ScrollPage extends WatchUi.View {
    const SCROLL_MS = 260;

    var focus as Number = 0;
    protected var _maxFocus as Number = 0;
    private var _offset as Float = 0.0;     // current scroll, px
    private var _from as Float = 0.0;
    private var _to as Float = 0.0;
    private var _animStart as Number = 0;
    private var _animating as Boolean = false;
    private var _buf as Graphics.BufferedBitmapReference? = null;
    private var _bufTop as Float = 0.0;     // content y the buffer starts at

    function initialize() {
        View.initialize();
    }

    // Scroll offset (px) that shows focus position f.
    function targetFor(f as Number, h as Number) as Float {
        return 0.0;
    }

    // Draws the scrolling content with its top at y0 (screen w x h).
    function drawContent(dc as Dc, w as Number, h as Number, y0 as Float) as Void {
    }

    // Drawn over the content, not scrolled (rings, overlays).
    function drawOverlay(dc as Dc) as Void {
    }

    function scrollTo(f as Number) as Void {
        if (f < 0 || f > _maxFocus || f == focus) { return; }
        focus = f;
        var h = System.getDeviceSettings().screenHeight;
        _from = _offset;
        _to = targetFor(f, h);
        _animStart = System.getTimer();
        _animating = true;
        _buf = null;
        getApp().ticker.fastFor(SCROLL_MS + 80);
        WatchUi.requestUpdate();
    }

    // Jumps without animation (e.g. when the page is built).
    function jumpTo(f as Number) as Void {
        focus = f;
        _offset = targetFor(f, System.getDeviceSettings().screenHeight);
        _to = _offset;
        _animating = false;
    }

    function offset() as Float {
        return _offset;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_animating) {
            var t = (System.getTimer() - _animStart).toFloat() / SCROLL_MS;
            if (t >= 1.0) {
                _animating = false;
                _offset = _to;
                _buf = null;
            } else {
                var e = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);   // ease-out
                _offset = _from + (_to - _from) * e;
            }
        }

        if (!_animating || !drawBuffered(dc, w, h)) {
            drawContent(dc, w, h, -_offset);
        }
        drawOverlay(dc);
    }

    // Draws the scroll frame from the off-screen copy; false if unavailable.
    private function drawBuffered(dc as Dc, w as Number, h as Number) as Boolean {
        if (!(Graphics has :createBufferedBitmap)) { return false; }
        var top = _from < _to ? _from : _to;
        var span = (_from - _to).abs();
        if (_buf == null) {
            _bufTop = top;
            _buf = Graphics.createBufferedBitmap({ :width => w, :height => (h + span).toNumber() + 2 });
            var b = _buf.get() as Graphics.BufferedBitmap?;
            if (b == null) { _buf = null; return false; }
            var bdc = b.getDc();
            bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            bdc.clear();
            drawContent(bdc, w, h, -top);
        }
        var ref = _buf;
        if (ref == null || ref.get() == null) { _buf = null; return false; }
        dc.drawBitmap(0, (_bufTop - _offset).toNumber(), ref);
        return true;
    }
}
