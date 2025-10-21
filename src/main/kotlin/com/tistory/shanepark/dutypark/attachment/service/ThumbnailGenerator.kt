package com.tistory.shanepark.dutypark.attachment.service

import java.nio.file.Path

interface ThumbnailGenerator {
    fun canGenerate(contentType: String): Boolean
    fun generate(sourcePath: Path, targetPath: Path, maxSide: Int)
}
