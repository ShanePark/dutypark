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
    @DisplayName("findMinTagOrderByMemberAndStatus Tests")
    inner class FindMinTagOrderByMemberAndStatusTests {

        @Test
        fun `should return null when member has no tagged todos in status`() {
            todoRepository.save(Todo(member1, "Own Task", "Content", 0, TodoStatus.TODO))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMinTagOrderByMemberAndStatus(member2, TodoStatus.TODO)

            assertThat(result).isNull()
        }

        @Test
        fun `should return minimum tagOrder for member and status`() {
            val first = Todo(member1, "Task 1", "Content", 0, TodoStatus.TODO)
            first.addTag(member2)
            first.tags.first().tagOrder = 5
            val second = Todo(member1, "Task 2", "Content", 0, TodoStatus.TODO)
            second.addTag(member2)
            second.tags.first().tagOrder = 2
            todoRepository.saveAll(listOf(first, second))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMinTagOrderByMemberAndStatus(member2, TodoStatus.TODO)

            assertThat(result).isEqualTo(2)
        }

        @Test
        fun `should handle negative tagOrder values`() {
            val todo = Todo(member1, "Task", "Content", 0, TodoStatus.TODO)
            todo.addTag(member2)
            todo.tags.first().tagOrder = -7
            todoRepository.save(todo)
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMinTagOrderByMemberAndStatus(member2, TodoStatus.TODO)

            assertThat(result).isEqualTo(-7)
        }

        @Test
        fun `should scope tagOrder by status`() {
            val todoStatusTagged = Todo(member1, "TODO Task", "Content", 0, TodoStatus.TODO)
            todoStatusTagged.addTag(member2)
            todoStatusTagged.tags.first().tagOrder = 3
            val inProgressTagged = Todo(member1, "IN_PROGRESS Task", "Content", 0, TodoStatus.IN_PROGRESS)
            inProgressTagged.addTag(member2)
            inProgressTagged.tags.first().tagOrder = -9
            todoRepository.saveAll(listOf(todoStatusTagged, inProgressTagged))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMinTagOrderByMemberAndStatus(member2, TodoStatus.TODO)

            // The IN_PROGRESS tag (-9) must not leak into the TODO query.
            assertThat(result).isEqualTo(3)
        }

        @Test
        fun `should scope tagOrder by member`() {
            val taggedMember2 = Todo(member1, "For member2", "Content", 0, TodoStatus.TODO)
            taggedMember2.addTag(member2)
            taggedMember2.tags.first().tagOrder = 4
            val taggedMember1 = Todo(member2, "For member1", "Content", 0, TodoStatus.TODO)
            taggedMember1.addTag(member1)
            taggedMember1.tags.first().tagOrder = -50
            todoRepository.saveAll(listOf(taggedMember2, taggedMember1))
            entityManager.flush()
            entityManager.clear()

            val result = todoRepository.findMinTagOrderByMemberAndStatus(member2, TodoStatus.TODO)

            // member1's tag (-50) must not leak into member2's query.
            assertThat(result).isEqualTo(4)
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
        fun `minimum should work correctly for single todo`() {
            todoRepository.save(Todo(member1, "Single", "Content", 5, TodoStatus.TODO))
            entityManager.flush()
            entityManager.clear()

            val min = todoRepository.findMinPositionByMemberAndStatus(member1, TodoStatus.TODO)

            assertThat(min).isEqualTo(5)
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

            assertThat(min).isEqualTo(0)
        }
    }
}
