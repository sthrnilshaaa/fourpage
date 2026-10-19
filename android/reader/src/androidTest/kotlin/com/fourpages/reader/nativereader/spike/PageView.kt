package com.fourpages.reader.nativereader.spike

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.view.MotionEvent
import android.view.VelocityTracker
import android.view.View
import android.view.animation.DecelerateInterpolator
import com.fourpages.reader.nativereader.core.ChapterPipeline
import com.fourpages.reader.nativereader.core.PageIndex
import com.fourpages.reader.nativereader.engine.layout.BlockLayout
import com.fourpages.reader.nativereader.engine.layout.LayoutParams
import com.fourpages.reader.nativereader.engine.parse.ImageBlock
import com.fourpages.reader.nativereader.engine.render.PageRenderer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.abs

/**
 * Spike page view: current page bitmap plus pre-rendered neighbours. Drag slides the current
 * page (next) or the previous page (back) with the other underneath; tap thirds turn pages.
 * No curl here: phase 0 measures frame cost and render latency, not the effect.
 */
class PageView(context: Context) : View(context) {
    data class Loc(val resourceIndex: Int, val page: Int)

    private lateinit var pipeline: ChapterPipeline
    private lateinit var params: LayoutParams
    private lateinit var scope: CoroutineScope
    private lateinit var renderer: PageRenderer
    private lateinit var geometry: BlockLayout

    @OptIn(ExperimentalCoroutinesApi::class)
    private val renderDispatcher = Dispatchers.Default.limitedParallelism(1)

    private var loc: Loc? = null
    private var cur: Bitmap? = null
    private var prev: Bitmap? = null
    private var next: Bitmap? = null
    private var prevLoc: Loc? = null
    private var nextLoc: Loc? = null
    private var dx = 0f
    private var downX = 0f
    private var downY = 0f
    private var dragging = false
    private var velocity: VelocityTracker? = null
    private var animator: ValueAnimator? = null
    private var pendingDrawEvent: String? = null

    var index: PageIndex? = null
        set(value) { field = value; invalidate() }
    var onFirstPage: (() -> Unit)? = null

    private val headerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = 12f * resources.displayMetrics.scaledDensity
        textAlign = Paint.Align.CENTER
    }
    private val shadowPaint = Paint().apply { color = 0x33000000 }

    fun bind(pipeline: ChapterPipeline, params: LayoutParams, scope: CoroutineScope) {
        this.pipeline = pipeline; this.params = params; this.scope = scope
        renderer = PageRenderer(params, pipeline.images::size, pipeline.images::bitmap)
        geometry = BlockLayout(params, pipeline.images::size)
        headerPaint.color = params.textColor
    }

    /** Shows [target] and logs [event] when its bitmap is first drawn. */
    fun show(target: Loc, event: String? = null) {
        scope.launch {
            val bmp = render(target, cur.takeIf { it !== prev && it !== next })
            loc = target; cur = bmp
            pendingDrawEvent = event
            dx = 0f
            invalidate()
            refreshNeighbours()
        }
    }

    fun currentGlobalPage(): Int? = loc?.let { l -> index?.globalPage(l.resourceIndex, l.page) }

    private suspend fun neighbour(of: Loc, dir: Int): Loc? {
        val laid = pipeline.ensure(of.resourceIndex)
        val p = of.page + dir
        return when {
            p in laid.pages.indices -> Loc(of.resourceIndex, p)
            dir > 0 && of.resourceIndex + 1 < pipeline.chapterCount -> Loc(of.resourceIndex + 1, 0)
            dir < 0 && of.resourceIndex > 0 -> Loc(of.resourceIndex - 1, pipeline.ensure(of.resourceIndex - 1).pages.lastIndex)
            else -> null
        }
    }

    private suspend fun refreshNeighbours() {
        val l = loc ?: return
        val n = neighbour(l, 1)
        val p = neighbour(l, -1)
        nextLoc = n; prevLoc = p
        next = n?.let { render(it, next.takeIf { b -> b !== cur }) }
        prev = p?.let { render(it, prev.takeIf { b -> b !== cur }) }
        invalidate()
    }

    private suspend fun render(target: Loc, reuse: Bitmap?): Bitmap = withContext(renderDispatcher) {
        val laid = pipeline.ensure(target.resourceIndex)
        val page = laid.pages[target.page.coerceIn(laid.pages.indices)]
        val blocks = if (page.lastLine < page.firstLine) IntRange.EMPTY
        else laid.lines[page.firstLine].blockIndex..laid.lines[page.lastLine].blockIndex
        pipeline.images.prepare(blocks.mapNotNull { (laid.chapter.blocks[it] as? ImageBlock)?.href })
        val layouts = geometry.layoutBlocks(laid.chapter, blocks)
        val bmp = reuse ?: Bitmap.createBitmap(params.widthPx, params.heightPx, Bitmap.Config.ARGB_8888)
        renderer.draw(Canvas(bmp), laid, page, layouts)
        bmp
    }

    override fun onDraw(canvas: Canvas) {
        val c = cur ?: return
        val w = width.toFloat()
        when {
            dx < 0 && next != null -> {
                canvas.drawBitmap(next!!, 0f, 0f, null)
                canvas.drawRect(w + dx, 0f, w + dx + 12f, height.toFloat(), shadowPaint)
                canvas.drawBitmap(c, dx, 0f, null)
            }
            dx > 0 && prev != null -> {
                canvas.drawBitmap(c, 0f, 0f, null)
                canvas.drawRect(dx, 0f, dx + 12f, height.toFloat(), shadowPaint)
                canvas.drawBitmap(prev!!, dx - w, 0f, null)
            }
            else -> canvas.drawBitmap(c, 0f, 0f, null)
        }
        drawHeader(canvas)
        if (onFirstPage != null) { onFirstPage!!.invoke(); onFirstPage = null }
        pendingDrawEvent?.let { SpikeLog.since(it); pendingDrawEvent = null }
    }

    private fun drawHeader(canvas: Canvas) {
        val l = loc ?: return
        val idx = index
        val text = if (idx == null) "page ${l.page + 1} of ? (chapter ${l.resourceIndex + 1})" else {
            val g = idx.globalPage(l.resourceIndex, l.page)
            "page ${g + 1} of ${idx.totalPages} · ${idx.pagesLeftInBook(g)} pages left in book"
        }
        canvas.drawText(text, width / 2f, params.paddingPx * 0.7f, headerPaint)
    }

    override fun onTouchEvent(e: MotionEvent): Boolean {
        if (cur == null || animator?.isRunning == true) return true
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = e.x; downY = e.y; dragging = false
                velocity = VelocityTracker.obtain().also { it.addMovement(e) }
            }
            MotionEvent.ACTION_MOVE -> {
                velocity?.addMovement(e)
                val d = e.x - downX
                if (!dragging && abs(d) > 24) { dragging = true; SpikeLog.mark("turn") }
                if (dragging) {
                    dx = d.coerceIn(if (next != null) -width.toFloat() else 0f, if (prev != null) width.toFloat() else 0f)
                    invalidate()
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                velocity?.addMovement(e)
                velocity?.computeCurrentVelocity(1000)
                val vx = velocity?.xVelocity ?: 0f
                velocity?.recycle(); velocity = null
                if (dragging) {
                    val commit = abs(dx) > width / 3f || abs(vx) > 1000 && vx * dx > 0
                    settle(if (commit && dx < 0) -1 else if (commit && dx > 0) 1 else 0)
                } else {
                    when {
                        e.x > width * 2 / 3f && next != null -> { SpikeLog.mark("turn"); dx = -1f; settle(-1) }
                        e.x < width / 3f && prev != null -> { SpikeLog.mark("turn"); dx = 1f; settle(1) }
                    }
                }
            }
        }
        return true
    }

    /** Animates to a turn (-1 next, 1 previous) or back to rest (0). */
    private fun settle(dir: Int) {
        val target = dir * width.toFloat()
        animator = ValueAnimator.ofFloat(dx, target).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener { dx = it.animatedValue as Float; invalidate() }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(a: android.animation.Animator) {
                    if (dir == -1) { prev = cur; cur = next; next = null; prevLoc = loc; loc = nextLoc }
                    if (dir == 1) { next = cur; cur = prev; prev = null; nextLoc = loc; loc = prevLoc }
                    dx = 0f
                    invalidate()
                    SpikeLog.since("turn", if (dir == 0) "turnCancel" else "turn")
                    if (dir != 0) scope.launch { refreshNeighbours() }
                }
            })
            start()
        }
    }
}
