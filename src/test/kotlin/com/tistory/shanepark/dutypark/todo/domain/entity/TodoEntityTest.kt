package com.tistory.shanepark.dutypark.todo.domain.entity

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import java.time.LocalDate
import java.time.LocalDateTime

@DisplayName("Todo Entity Tests")
class TodoEntityTest {

    private lateinit var member: Member

    @BeforeEach
    fun setUp() {
        member = Member(name = "testUser", password = "password")
    }

    @Nested
    @DisplayName("Constructor Tests")
    inner class ConstructorTests {

        @Test
        fun `should create todo with default values`() {
            val todo = Todo(
                member = member,
                title = "Test Title",
                content = "Test Content",
                position = 0
            )

            assertEquals("Test Title", todo.title)
            assertEquals("Test Content", todo.content)
            assertEquals(0, todo.position)
            assertEquals(TodoStatus.TODO, todo.status)
            assertNull(todo.completedDate)
            assertNull(todo.dueDate)
        }

        @Test
        fun `should create todo with explicit status`() {
            val todo = Todo(
                member = member,
                title = "Test",
                content = "Content",
                position = 0,
                status = TodoStatus.IN_PROGRESS
            )

            assertEquals(TodoStatus.IN_PROGRESS, todo.status)
        }

        @Test
        fun `should create todo with due date`() {
            val dueDate = LocalDate.of(2025, 12, 31)
            val todo = Todo(
                member = member,
                title = "Test",
                content = "Content",
                position = 0
            )
            todo.dueDate = dueDate

            assertEquals(dueDate, todo.dueDate)
        }

        @Test
        fun `should create todo with negative position`() {
            val todo = Todo(
                member = member,
                title = "Test",
                content = "Content",
                position = -5
            )

            assertEquals(-5, todo.position)
        }

        @Test
        fun `should create todo with empty content`() {
            val todo = Todo(
                member = member,
                title = "Test",
                content = "",
                position = 0
            )

            assertEquals("", todo.content)
        }
    }

    @Nested
    @DisplayName("update() Tests")
    inner class UpdateTests {

        @Test
        fun `should update title and content`() {
            val todo = Todo(member, "Old Title", "Old Content", 0)

            todo.update("New Title", "New Content")

            assertEquals("New Title", todo.title)
            assertEquals("New Content", todo.content)
        }

        @Test
        fun `should update with empty content`() {
            val todo = Todo(member, "Title", "Content", 0)

            todo.update("Title", "")

            assertEquals("", todo.content)
        }

        @Test
        fun `should not change other fields when updating`() {
            val todo = Todo(member, "Title", "Content", 5, TodoStatus.IN_PROGRESS)
            todo.dueDate = LocalDate.of(2025, 1, 15)

            todo.update("New Title", "New Content")

            assertEquals(5, todo.position)
            assertEquals(TodoStatus.IN_PROGRESS, todo.status)
            assertEquals(LocalDate.of(2025, 1, 15), todo.dueDate)
        }

        @Test
        fun `should allow title with max length 50 characters`() {
            val todo = Todo(member, "Short", "Content", 0)
            val maxLengthTitle = "A".repeat(50)

            todo.update(maxLengthTitle, "Content")

            assertEquals(50, todo.title.length)
        }
    }

    @Nested
    @DisplayName("changeStatus() Tests")
    inner class ChangeStatusTests {

        @Test
        fun `should change status from TODO to IN_PROGRESS`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)

            todo.changeStatus(TodoStatus.IN_PROGRESS, 0)

            assertEquals(TodoStatus.IN_PROGRESS, todo.status)
            assertEquals(0, todo.position)
            assertNull(todo.completedDate)
        }

        @Test
        fun `should change status from TODO to DONE and set completedDate`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)

            todo.changeStatus(TodoStatus.DONE, 0)

            assertEquals(TodoStatus.DONE, todo.status)
            assertNotNull(todo.completedDate)
        }

        @Test
        fun `should change status from IN_PROGRESS to TODO`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.IN_PROGRESS)

            todo.changeStatus(TodoStatus.TODO, 5)

            assertEquals(TodoStatus.TODO, todo.status)
            assertEquals(5, todo.position)
            assertNull(todo.completedDate)
        }

        @Test
        fun `should change status from IN_PROGRESS to DONE and set completedDate`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.IN_PROGRESS)

            todo.changeStatus(TodoStatus.DONE, 0)

            assertEquals(TodoStatus.DONE, todo.status)
            assertNotNull(todo.completedDate)
        }

        @Test
        fun `should change status from DONE to TODO and clear completedDate`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.DONE)
            todo.markCompleted(0)
            assertNotNull(todo.completedDate)

            todo.changeStatus(TodoStatus.TODO, 0)

            assertEquals(TodoStatus.TODO, todo.status)
            assertNull(todo.completedDate)
        }

        @Test
        fun `should change status from DONE to IN_PROGRESS and clear completedDate`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.DONE)
            todo.markCompleted(0)
            assertNotNull(todo.completedDate)

            todo.changeStatus(TodoStatus.IN_PROGRESS, 3)

            assertEquals(TodoStatus.IN_PROGRESS, todo.status)
            assertEquals(3, todo.position)
            assertNull(todo.completedDate)
        }

        @Test
        fun `should update position when changing to same status`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)

            todo.changeStatus(TodoStatus.TODO, 10)

            assertEquals(TodoStatus.TODO, todo.status)
            assertEquals(10, todo.position)
        }

        @Test
        fun `should not set completedDate when already DONE`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.DONE)
            val originalCompletedDate = LocalDateTime.of(2025, 1, 1, 12, 0)
            todo.completedDate = originalCompletedDate

            todo.changeStatus(TodoStatus.DONE, 5)

            assertEquals(originalCompletedDate, todo.completedDate)
            assertEquals(5, todo.position)
        }

        @Test
        fun `should handle negative position`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)

            todo.changeStatus(TodoStatus.IN_PROGRESS, -10)

            assertEquals(-10, todo.position)
        }
    }

    @Nested
    @DisplayName("markCompleted() Tests")
    inner class MarkCompletedTests {

        @Test
        fun `should set status to DONE`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)

            todo.markCompleted(0)

            assertEquals(TodoStatus.DONE, todo.status)
        }

        @Test
        fun `should set completedDate to now by default`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)

            todo.markCompleted(0)

            assertNotNull(todo.completedDate)
        }

        @Test
        fun `should set completedDate to provided time`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)
            val specificTime = LocalDateTime.of(2025, 6, 15, 14, 30)

            todo.markCompleted(0, specificTime)

            assertEquals(specificTime, todo.completedDate)
        }

        @Test
        fun `should set position to provided value`() {
            val todo = Todo(member, "Title", "Content", 5, TodoStatus.TODO)

            todo.markCompleted(10)

            assertEquals(10, todo.position)
        }

        @Test
        fun `should work from IN_PROGRESS status`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.IN_PROGRESS)

            todo.markCompleted(0)

            assertEquals(TodoStatus.DONE, todo.status)
            assertNotNull(todo.completedDate)
        }
    }

    @Nested
    @DisplayName("markActive() Tests")
    inner class MarkActiveTests {

        @Test
        fun `should set status to TODO`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.DONE)
            todo.markCompleted(0)

            todo.markActive(0)

            assertEquals(TodoStatus.TODO, todo.status)
        }

        @Test
        fun `should clear completedDate`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.DONE)
            todo.markCompleted(0)
            assertNotNull(todo.completedDate)

            todo.markActive(0)

            assertNull(todo.completedDate)
        }

        @Test
        fun `should set position to provided value`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.DONE)
            todo.markCompleted(0)

            todo.markActive(15)

            assertEquals(15, todo.position)
        }

        @Test
        fun `should work with negative position`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.DONE)
            todo.markCompleted(0)

            todo.markActive(-1)

            assertEquals(-1, todo.position)
        }
    }

    @Nested
    @DisplayName("dueDate Tests")
    inner class DueDateTests {

        @Test
        fun `should allow setting due date`() {
            val todo = Todo(member, "Title", "Content", 0)
            val dueDate = LocalDate.of(2025, 12, 31)

            todo.dueDate = dueDate

            assertEquals(dueDate, todo.dueDate)
        }

        @Test
        fun `should allow clearing due date`() {
            val todo = Todo(member, "Title", "Content", 0)
            todo.dueDate = LocalDate.of(2025, 12, 31)

            todo.dueDate = null

            assertNull(todo.dueDate)
        }

        @Test
        fun `should allow past due date`() {
            val todo = Todo(member, "Title", "Content", 0)
            val pastDate = LocalDate.of(2020, 1, 1)

            todo.dueDate = pastDate

            assertEquals(pastDate, todo.dueDate)
        }

        @Test
        fun `due date should not affect status transitions`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)
            todo.dueDate = LocalDate.of(2020, 1, 1)

            todo.changeStatus(TodoStatus.DONE, 0)

            assertEquals(LocalDate.of(2020, 1, 1), todo.dueDate)
            assertEquals(TodoStatus.DONE, todo.status)
        }
    }

    @Nested
    @DisplayName("Edge Cases")
    inner class EdgeCases {

        @Test
        fun `should preserve member reference across status changes`() {
            val todo = Todo(member, "Title", "Content", 0)

            todo.changeStatus(TodoStatus.IN_PROGRESS, 0)
            todo.changeStatus(TodoStatus.DONE, 0)
            todo.changeStatus(TodoStatus.TODO, 0)

            assertSame(member, todo.member)
        }

        @Test
        fun `should handle rapid status changes`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)

            todo.changeStatus(TodoStatus.IN_PROGRESS, 1)
            todo.changeStatus(TodoStatus.DONE, 2)
            todo.changeStatus(TodoStatus.TODO, 3)
            todo.changeStatus(TodoStatus.DONE, 4)

            assertEquals(TodoStatus.DONE, todo.status)
            assertEquals(4, todo.position)
            assertNotNull(todo.completedDate)
        }

        @Test
        fun `completedDate should update each time transitioning to DONE`() {
            val todo = Todo(member, "Title", "Content", 0, TodoStatus.TODO)

            todo.changeStatus(TodoStatus.DONE, 0)
            val firstCompletedDate = todo.completedDate

            todo.changeStatus(TodoStatus.TODO, 0)
            todo.changeStatus(TodoStatus.DONE, 0)
            val secondCompletedDate = todo.completedDate

            assertNotNull(firstCompletedDate)
            assertNotNull(secondCompletedDate)
        }
    }
}
