package com.fourpages.reader.nativereader.engine.render

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.text.StaticLayout
import android.util.Size
import com.fourpages.reader.nativereader.core.Highlight
import com.fourpages.reader.nativereader.engine.layout.BlockLayout
import com.fourpages.reader.nativereader.engine.layout.LaidOutChapter
import com.fourpages.reader.nativereader.engine.layout.LayoutParams
import com.fourpages.reader.nativereader.engine.layout.Page
import com.fourpages.reader.nativereader.engine.parse.ImageBlock
import com.fourpages.reader.nativereader.engine.parse.SeparatorBlock
import com.fourpages.reader.nativereader.engine.parse.TextBlock

/** Draws one page of a laid-out chapter. Layout geometry comes from [BlockLayout] with the same params. */
class PageRenderer(
    private val params: LayoutParams,
    private val imageSize: (href: String) -> Size? = { null },
    private val imageBitmap: (href: String) -> Bitmap?,
) {
    constructor(params: LayoutParams, imageBitmap: (href: String) -> Bitmap?) :
        this(params, { href -> imageBitmap(href)?.let { Size(it.width, it.height) } }, imageBitmap)

    private val geometry = BlockLayout(params, imageSize)
    private val inkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = params.textColor; strokeWidth = 2f }
    private val highlightPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private val altPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = params.textColor; textSize = params.textSizePx * 0.85f; textAlign = Paint.Align.CENTER
    }

    fun draw(
        canvas: Canvas,
        laid: LaidOutChapter,
        page: Page,
        layouts: Map<Int, StaticLayout>,
        highlights: List<Highlight> = emptyList(),
    ) {
        val mine = highlights.filter { it.resourceIndex == laid.chapter.resourceIndex }
        canvas.drawColor(params.backgroundColor)
        if (page.lastLine < page.firstLine) return
        val lines = laid.lines
        val pageTop = lines[page.firstLine].top
        val pageBottom = lines[page.lastLine].bottom
        canvas.save()
        canvas.translate(params.paddingPx.toFloat(), (params.paddingPx - pageTop).toFloat())
        canvas.clipRect(0, pageTop, params.contentWidth, pageBottom)
        var i = page.firstLine
        while (i <= page.lastLine) {
            val blockIndex = lines[i].blockIndex
            val block = laid.chapter.blocks[blockIndex]
            // Block top = top of its first line (which may be on an earlier page).
            var first = i
            while (first > 0 && lines[first - 1].blockIndex == blockIndex) first--
            val blockTop = lines[first].top
            when (block) {
                is TextBlock -> layouts[blockIndex]?.let { sl ->
                    canvas.save()
                    canvas.translate(geometry.insetPx(block).toFloat(), blockTop.toFloat())
                    drawHighlights(canvas, sl, block, mine)
                    sl.draw(canvas)
                    canvas.restore()
                }
                is ImageBlock -> drawImage(canvas, block, lines[i].top, lines[i].bottom)
                is SeparatorBlock -> {
                    val mid = (lines[i].top + lines[i].bottom) / 2f
                    val w = params.contentWidth / 4f
                    canvas.drawLine(params.contentWidth / 2f - w / 2, mid, params.contentWidth / 2f + w / 2, mid, inkPaint)
                }
            }
            while (i <= page.lastLine && lines[i].blockIndex == blockIndex) i++
        }
        canvas.restore()
    }

    fun renderToBitmap(
        laid: LaidOutChapter,
        page: Page,
        layouts: Map<Int, StaticLayout>,
        highlights: List<Highlight> = emptyList(),
    ): Bitmap = Bitmap.createBitmap(params.widthPx, params.heightPx, Bitmap.Config.ARGB_8888).also {
        draw(Canvas(it), laid, page, layouts, highlights)
    }

    /** Highlight backgrounds for the parts of [block] the highlights cover, under the text. */
    private fun drawHighlights(canvas: Canvas, sl: StaticLayout, block: TextBlock, highlights: List<Highlight>) {
        for (h in highlights) {
            val a = (h.start - block.charStart).coerceIn(0, block.text.length)
            val b = (h.end - block.charStart).coerceIn(0, block.text.length)
            if (b <= a) continue
            val path = Path()
            sl.getSelectionPath(a, b, path)
            highlightPaint.color = (h.color and 0x00FFFFFF) or (0x66 shl 24)
            canvas.drawPath(path, highlightPaint)
        }
    }

    private fun drawImage(canvas: Canvas, block: ImageBlock, top: Int, bottom: Int) {
        val size = geometry.imageDrawSize(block)
        val bmp = imageBitmap(block.href)
        if (size == null || bmp == null) {
            val label = block.alt.ifEmpty { "[image]" }
            canvas.drawText(label, params.contentWidth / 2f, (top + bottom) / 2f + altPaint.textSize / 3, altPaint)
            return
        }
        val left = (params.contentWidth - size.width) / 2f
        canvas.drawBitmap(bmp, Rect(0, 0, bmp.width, bmp.height), RectF(left, top.toFloat(), left + size.width, top + size.height.toFloat()), bitmapPaint)
    }
}
