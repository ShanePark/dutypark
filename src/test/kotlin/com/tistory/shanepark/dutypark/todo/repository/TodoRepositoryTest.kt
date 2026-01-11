package com.tistory.shanepark.dutypark.todo.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager
import java.time.LocalDate
import java.time.LocalDateTime

@DataJpaTest
@DisplayName("TodoRepository Tests")
class TodoRepositoryTest {

    @Autowired
    private lateinit var todoRepository: TodoRepository

    @Autowired
    private lateinit var entityManager: TestEntityManager

    private lateinit var member1: Member
    private lateinit var member2: Member

    @BeforeEach
    fun setUp() {
        member1 = entityManager.persist(Member(name = "user1", password = "pass", email = "user1@test.com"))
        member2 = entityManager.persist(Member(name = "user2", password = "pass", email = "user2@test.com"))
        entityManager.flush()
        entityManager.clear()
    }

    @Nested
    @DisplayName("findMinPositionByMemberAndStatus Tests")
    inner class FindMinPositionByMemberAndStatusTests {

        @Test
        fun `should return 0 when no todos exist for member and status`() {
            val result = todoRepository.findMinPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(result).isEqualTo(0)
        }

        @Test
        fun `should return minimum position for given status`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Task 1", "Content", 5, TodoStatus.TODO),
                    Todo(member1, "Task 2", "Content", 3, TodoStatus.TODO),
                    Todo(member1, "Task 3", "Content", 7, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMinPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(result).isEqualTo(3)
        }

        @Test
        fun `should handle negative positions`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Task 1", "Content", -5, TodoStatus.TODO),
                    Todo(member1, "Task 2", "Content", -10, TodoStatus.TODO),
                    Todo(member1, "Task 3", "Content", 0, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMinPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(result).isEqualTo(-10)
        }

        @Test
        fun `should only consider todos with matching status`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "TODO Task", "Content", 10, TodoStatus.TODO),
                    Todo(member1, "IN_PROGRESS Task", "Content", 1, TodoStatus.IN_PROGRESS),
                    Todo(member1, "DONE Task", "Content", 5, TodoStatus.DONE)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMinPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(result).isEqualTo(10)
        }

        @Test
        fun `should isolate by member`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Member1 Task", "Content", 5, TodoStatus.TODO),
                    Todo(member2, "Member2 Task", "Content", 1, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMinPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(result).isEqualTo(5)
        }
    }

    @Nested
    @DisplayName("findMaxPositionByMemberAndStatus Tests")
    inner class FindMaxPositionByMemberAndStatusTests {

        @Test
        fun `should return -1 when no todos exist`() {
            val result = todoRepository.findMaxPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(result).isEqualTo(-1)
        }

        @Test
        fun `should return maximum position for given status`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Task 1", "Content", 5, TodoStatus.TODO),
                    Todo(member1, "Task 2", "Content", 10, TodoStatus.TODO),
                    Todo(member1, "Task 3", "Content", 3, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMaxPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(result).isEqualTo(10)
        }

        @Test
        fun `should handle all negative positions`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Task 1", "Content", -5, TodoStatus.TODO),
                    Todo(member1, "Task 2", "Content", -10, TodoStatus.TODO),
                    Todo(member1, "Task 3", "Content", -1, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMaxPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(result).isEqualTo(-1)
        }
    }

    @Nested
    @DisplayName("Member Isolation Tests")
    inner class MemberIsolationTests {

        @Test
        fun `findAllByMemberAndStatusOrderByPosition should only return member's todos`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Member1 TODO 1", "Content", 0, TodoStatus.TODO),
                    Todo(member1, "Member1 TODO 2", "Content", 1, TodoStatus.TODO),
                    Todo(member2, "Member2 TODO 1", "Content", 0, TodoStatus.TODO),
                    Todo(member2, "Member2 TODO 2", "Content", 1, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndStatusOrderByPosition(member1, TodoStatus.TODO)

            assertThat(result).hasSize(2)
            assertThat(result.map { it.title }).containsExactlyInAnyOrder("Member1 TODO 1", "Member1 TODO 2")
        }

        @Test
        fun `findAllByMemberOrderByStatusAscPositionAsc should only return member's todos`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Member1 Task", "Content", 0, TodoStatus.TODO),
                    Todo(member2, "Member2 Task", "Content", 0, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberOrderByStatusAscPositionAsc(member1)

            assertThat(result).hasSize(1)
            assertThat(result[0].title).isEqualTo("Member1 Task")
        }
    }

    @Nested
    @DisplayName("Ordering Tests")
    inner class OrderingTests {

        @Test
        fun `should order by position ascending`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Third", "Content", 10, TodoStatus.TODO),
                    Todo(member1, "First", "Content", -5, TodoStatus.TODO),
                    Todo(member1, "Second", "Content", 0, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndStatusOrderByPositionAsc(member1, TodoStatus.TODO)

            assertThat(result).hasSize(3)
            assertThat(result.map { it.title }).containsExactly("First", "Second", "Third")
        }

        @Test
        fun `should order by completed date descending for DONE todos`() {
            val todo1 = Todo(member1, "First Completed", "Content", 0, TodoStatus.DONE)
            todo1.completedDate = LocalDateTime.of(2025, 1, 1, 10, 0)

            val todo2 = Todo(member1, "Second Completed", "Content", 1, TodoStatus.DONE)
            todo2.completedDate = LocalDateTime.of(2025, 1, 3, 10, 0)

            val todo3 = Todo(member1, "Third Completed", "Content", 2, TodoStatus.DONE)
            todo3.completedDate = LocalDateTime.of(2025, 1, 2, 10, 0)

            todoRepository.saveAll(listOf(todo1, todo2, todo3))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndStatusOrderByCompletedDateDesc(member1, TodoStatus.DONE)

            assertThat(result).hasSize(3)
            assertThat(result.map { it.title }).containsExactly("Second Completed", "Third Completed", "First Completed")
        }

        @Test
        fun `findAllByMemberOrderByStatusAscPositionAsc should order by status then position`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "TODO 2", "Content", 1, TodoStatus.TODO),
                    Todo(member1, "DONE 1", "Content", 0, TodoStatus.DONE),
                    Todo(member1, "TODO 1", "Content", 0, TodoStatus.TODO),
                    Todo(member1, "IN_PROGRESS 1", "Content", 0, TodoStatus.IN_PROGRESS)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberOrderByStatusAscPositionAsc(member1)

            assertThat(result).hasSize(4)
        }
    }

    @Nested
    @DisplayName("Due Date Query Tests")
    inner class DueDateQueryTests {

        @Test
        fun `findAllByMemberAndDueDateBetweenOrderByDueDateAsc should return todos within date range`() {
            val todo1 = Todo(member1, "Jan 15", "Content", 0, TodoStatus.TODO)
            todo1.dueDate = LocalDate.of(2025, 1, 15)

            val todo2 = Todo(member1, "Jan 20", "Content", 1, TodoStatus.TODO)
            todo2.dueDate = LocalDate.of(2025, 1, 20)

            val todo3 = Todo(member1, "Feb 5", "Content", 2, TodoStatus.TODO)
            todo3.dueDate = LocalDate.of(2025, 2, 5)

            val todo4 = Todo(member1, "No due date", "Content", 3, TodoStatus.TODO)

            todoRepository.saveAll(listOf(todo1, todo2, todo3, todo4))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndDueDateBetweenOrderByDueDateAsc(
                member1,
                LocalDate.of(2025, 1, 1),
                LocalDate.of(2025, 1, 31)
            )

            assertThat(result).hasSize(2)
            assertThat(result.map { it.title }).containsExactly("Jan 15", "Jan 20")
        }

        @Test
        fun `findAllByMemberAndDueDateBetweenOrderByDueDateAsc should handle boundary dates`() {
            val todo1 = Todo(member1, "First day", "Content", 0, TodoStatus.TODO)
            todo1.dueDate = LocalDate.of(2025, 1, 1)

            val todo2 = Todo(member1, "Last day", "Content", 1, TodoStatus.TODO)
            todo2.dueDate = LocalDate.of(2025, 1, 31)

            todoRepository.saveAll(listOf(todo1, todo2))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndDueDateBetweenOrderByDueDateAsc(
                member1,
                LocalDate.of(2025, 1, 1),
                LocalDate.of(2025, 1, 31)
            )

            assertThat(result).hasSize(2)
        }

        @Test
        fun `findAllByMemberAndDueDateBetweenOrderByDueDateAsc should handle leap year February`() {
            val todo1 = Todo(member1, "Feb 29 2024", "Content", 0, TodoStatus.TODO)
            todo1.dueDate = LocalDate.of(2024, 2, 29)

            todoRepository.save(todo1)
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndDueDateBetweenOrderByDueDateAsc(
                member1,
                LocalDate.of(2024, 2, 1),
                LocalDate.of(2024, 2, 29)
            )

            assertThat(result).hasSize(1)
            assertThat(result[0].dueDate).isEqualTo(LocalDate.of(2024, 2, 29))
        }

        @Test
        fun `findAllByMemberAndDueDateOrderByPositionAsc should return todos with specific due date`() {
            val targetDate = LocalDate.of(2025, 6, 15)

            val todo1 = Todo(member1, "Task 1", "Content", 1, TodoStatus.TODO)
            todo1.dueDate = targetDate

            val todo2 = Todo(member1, "Task 2", "Content", 0, TodoStatus.TODO)
            todo2.dueDate = targetDate

            val todo3 = Todo(member1, "Other date", "Content", 2, TodoStatus.TODO)
            todo3.dueDate = LocalDate.of(2025, 6, 16)

            todoRepository.saveAll(listOf(todo1, todo2, todo3))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndDueDateOrderByPositionAsc(member1, targetDate)

            assertThat(result).hasSize(2)
            assertThat(result.map { it.title }).containsExactly("Task 2", "Task 1")
        }
    }

    @Nested
    @DisplayName("Overdue Query Tests")
    inner class OverdueQueryTests {

        @Test
        fun `findAllByMemberAndDueDateLessThanAndStatusNot should return overdue non-DONE todos`() {
            val today = LocalDate.now()

            val overdueTodo = Todo(member1, "Overdue TODO", "Content", 0, TodoStatus.TODO)
            overdueTodo.dueDate = today.minusDays(1)

            val overdueInProgress = Todo(member1, "Overdue IN_PROGRESS", "Content", 0, TodoStatus.IN_PROGRESS)
            overdueInProgress.dueDate = today.minusDays(2)

            val overdueDone = Todo(member1, "Overdue but DONE", "Content", 0, TodoStatus.DONE)
            overdueDone.dueDate = today.minusDays(3)

            val notOverdue = Todo(member1, "Future TODO", "Content", 0, TodoStatus.TODO)
            notOverdue.dueDate = today.plusDays(1)

            val noDueDate = Todo(member1, "No due date", "Content", 0, TodoStatus.TODO)

            todoRepository.saveAll(listOf(overdueTodo, overdueInProgress, overdueDone, notOverdue, noDueDate))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndDueDateLessThanAndStatusNot(
                member1,
                today,
                TodoStatus.DONE
            )

            assertThat(result).hasSize(2)
            assertThat(result.map { it.title }).containsExactlyInAnyOrder("Overdue TODO", "Overdue IN_PROGRESS")
        }

        @Test
        fun `overdue query should exclude todos with null dueDate`() {
            val today = LocalDate.now()

            val todoWithNullDueDate = Todo(member1, "No due date", "Content", 0, TodoStatus.TODO)

            todoRepository.save(todoWithNullDueDate)
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndDueDateLessThanAndStatusNot(
                member1,
                today,
                TodoStatus.DONE
            )

            assertThat(result).isEmpty()
        }

        @Test
        fun `overdue query boundary - dueDate equals today should not be returned`() {
            val today = LocalDate.now()

            val todayTodo = Todo(member1, "Due today", "Content", 0, TodoStatus.TODO)
            todayTodo.dueDate = today

            todoRepository.save(todayTodo)
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndDueDateLessThanAndStatusNot(
                member1,
                today,
                TodoStatus.DONE
            )

            assertThat(result).isEmpty()
        }
    }

    @Nested
    @DisplayName("Empty Result Tests")
    inner class EmptyResultTests {

        @Test
        fun `should return empty list when member has no todos`() {
            val result = todoRepository.findAllByMemberAndStatusOrderByPosition(member1, TodoStatus.TODO)

            assertThat(result).isEmpty()
        }

        @Test
        fun `should return empty list when status has no todos`() {
            todoRepository.save(Todo(member1, "Task", "Content", 0, TodoStatus.TODO))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findAllByMemberAndStatusOrderByPosition(member1, TodoStatus.IN_PROGRESS)

            assertThat(result).isEmpty()
        }

        @Test
        fun `should return empty list for date range with no todos`() {
            val result = todoRepository.findAllByMemberAndDueDateBetweenOrderByDueDateAsc(
                member1,
                LocalDate.of(2025, 1, 1),
                LocalDate.of(2025, 1, 31)
            )

            assertThat(result).isEmpty()
        }
    }

    @Nested
    @DisplayName("Position Calculation Edge Cases")
    inner class PositionCalculationTests {

        @Test
        fun `should correctly calculate new position for adding to top of TODO column`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Existing 1", "Content", 0, TodoStatus.TODO),
                    Todo(member1, "Existing 2", "Content", 1, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val minPosition = todoRepository.findMinPositionByMemberAndStatus(member1, TodoStatus.TODO)
            val newPosition = minPosition - 1

            assertThat(newPosition).isEqualTo(-1)
        }

        @Test
        fun `should correctly calculate new position for adding to bottom of column`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Existing 1", "Content", 0, TodoStatus.TODO),
                    Todo(member1, "Existing 2", "Content", 1, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val maxPosition = todoRepository.findMaxPositionByMemberAndStatus(member1, TodoStatus.TODO)
            val newPosition = maxPosition + 1

            assertThat(newPosition).isEqualTo(2)
        }

        @Test
        fun `min and max should work correctly for single todo`() {
            todoRepository.save(Todo(member1, "Single", "Content", 5, TodoStatus.TODO))
            entityManager.flush()
            entityManager.clear()

            val min = todoRepository.findMinPositionByMemberAndStatus(member1, TodoStatus.TODO)
            val max = todoRepository.findMaxPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(min).isEqualTo(5)
            assertThat(max).isEqualTo(5)
        }

        @Test
        fun `should handle position gaps correctly`() {
            todoRepository.saveAll(
                listOf(
                    Todo(member1, "Task", "Content", 0, TodoStatus.TODO),
                    Todo(member1, "Task", "Content", 5, TodoStatus.TODO),
                    Todo(member1, "Task", "Content", 100, TodoStatus.TODO)
                )
            )
            entityManager.flush()
            entityManager.clear()

            val min = todoRepository.findMinPositionByMemberAndStatus(member1, TodoStatus.TODO)
            val max = todoRepository.findMaxPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(min).isEqualTo(0)
            assertThat(max).isEqualTo(100)
        }
    }
}
