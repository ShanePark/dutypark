package com.tistory.shanepark.dutypark.attachment.service

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.awt.Color
import java.awt.image.BufferedImage
import java.nio.file.Files
import java.nio.file.Path
import javax.imageio.ImageIO

class ImageThumbnailGeneratorTest {

    private lateinit var generator: ImageThumbnailGenerator

    @TempDir
    lateinit var tempDir: Path

    @BeforeEach
    fun setUp() {
        generator = ImageThumbnailGenerator()
    }

    @Test
    fun `should support common image formats`() {
        assertThat(generator.canGenerate("image/jpeg")).isTrue()
        assertThat(generator.canGenerate("image/jpg")).isTrue()
        assertThat(generator.canGenerate("image/png")).isTrue()
        assertThat(generator.canGenerate("image/gif")).isTrue()
        assertThat(generator.canGenerate("image/bmp")).isTrue()
        assertThat(generator.canGenerate("image/webp")).isTrue()
        assertThat(generator.canGenerate("image/tiff")).isTrue()
    }

    @Test
    fun `should not support non-image formats`() {
        assertThat(generator.canGenerate("application/pdf")).isFalse()
        assertThat(generator.canGenerate("text/plain")).isFalse()
        assertThat(generator.canGenerate("video/mp4")).isFalse()
    }

    @Test
    fun `should be case insensitive for content type`() {
        assertThat(generator.canGenerate("IMAGE/JPEG")).isTrue()
        assertThat(generator.canGenerate("Image/Png")).isTrue()
    }

    @Test
    fun `should generate thumbnail with max side constraint`() {
        val sourceImage = createTestImage(800, 600, Color.BLUE)
        val sourcePath = tempDir.resolve("source.png")
        ImageIO.write(sourceImage, "png", sourcePath.toFile())

        val targetPath = tempDir.resolve("thumb.png")

        generator.generate(sourcePath, targetPath, 200)

        assertThat(Files.exists(targetPath)).isTrue()

        val thumbnail = ImageIO.read(targetPath.toFile())
        assertThat(thumbnail.width).isLessThanOrEqualTo(200)
        assertThat(thumbnail.height).isLessThanOrEqualTo(200)
        assertThat(thumbnail.width).isEqualTo(200)
        assertThat(thumbnail.height).isEqualTo(150)
    }

    @Test
    fun `should maintain aspect ratio when scaling`() {
        val sourceImage = createTestImage(1600, 800, Color.RED)
        val sourcePath = tempDir.resolve("wide.png")
        ImageIO.write(sourceImage, "png", sourcePath.toFile())

        val targetPath = tempDir.resolve("thumb-wide.png")

        generator.generate(sourcePath, targetPath, 200)

        val thumbnail = ImageIO.read(targetPath.toFile())
        assertThat(thumbnail.width).isEqualTo(200)
        assertThat(thumbnail.height).isEqualTo(100)
    }

    @Test
    fun `should handle tall images`() {
        val sourceImage = createTestImage(600, 1200, Color.GREEN)
        val sourcePath = tempDir.resolve("tall.png")
        ImageIO.write(sourceImage, "png", sourcePath.toFile())

        val targetPath = tempDir.resolve("thumb-tall.png")

        generator.generate(sourcePath, targetPath, 200)

        val thumbnail = ImageIO.read(targetPath.toFile())
        assertThat(thumbnail.width).isEqualTo(100)
        assertThat(thumbnail.height).isEqualTo(200)
    }

    @Test
    fun `should handle small images`() {
        val sourceImage = createTestImage(100, 80, Color.YELLOW)
        val sourcePath = tempDir.resolve("small.png")
        ImageIO.write(sourceImage, "png", sourcePath.toFile())

        val targetPath = tempDir.resolve("thumb-small.png")

        generator.generate(sourcePath, targetPath, 200)

        val thumbnail = ImageIO.read(targetPath.toFile())
        assertThat(thumbnail.width).isLessThanOrEqualTo(200)
        assertThat(thumbnail.height).isLessThanOrEqualTo(200)
    }

    @Test
    fun `should throw exception for invalid image file`() {
        val invalidPath = tempDir.resolve("invalid.png")
        Files.write(invalidPath, "not an image".toByteArray())

        val targetPath = tempDir.resolve("thumb.png")

        assertThatThrownBy {
            generator.generate(invalidPath, targetPath, 200)
        }.isInstanceOf(Exception::class.java)
    }

    private fun createTestImage(width: Int, height: Int, color: Color): BufferedImage {
        val image = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)
        val graphics = image.createGraphics()
        graphics.color = color
        graphics.fillRect(0, 0, width, height)
        graphics.dispose()
        return image
    }
}
