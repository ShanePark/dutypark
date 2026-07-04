-- Recover member.created_date with the earliest observable activity.
-- Old schedules were backfilled to a single timestamp in V2.0.22, so for those rows
-- we infer a better creation moment from the schedule id itself:
-- - legacy UUID v1 rows keep their timestamp in the UUID fields
-- - ULID-backed UUID rows keep their timestamp in the first 48 bits
--
-- Dutypark stores LocalDateTime values in KST, while MySQL's FROM_UNIXTIME here is UTC,
-- so we add 9 hours to align with existing application-written timestamps.
with
    schedule_backfill as (
        select installed_on as installed_at
        from flyway_schema_history
        where version = '2.0.22'
        order by installed_rank desc
        limit 1
    ),
    inferred_schedule_activity as (
        select
            s.member_id,
            min(
                case
                    when s.created_date = sb.installed_at then
                        greatest(
                            case
                                when date_add(
                                    from_unixtime(
                                        cast(conv(substring(replace(s.id, '-', ''), 1, 12), 16, 10) as unsigned) / 1000
                                    ),
                                    interval 9 hour
                                ) < sb.installed_at
                                    then date_add(
                                    from_unixtime(
                                        cast(conv(substring(replace(s.id, '-', ''), 1, 12), 16, 10) as unsigned) / 1000
                                    ),
                                    interval 9 hour
                                )
                                else timestamp('1000-01-01 00:00:00')
                            end,
                            case
                                when date_add(
                                    from_unixtime(
                                        (
                                            cast(
                                                conv(
                                                    concat(
                                                        substring(replace(s.id, '-', ''), 14, 3),
                                                        substring(replace(s.id, '-', ''), 9, 4),
                                                        substring(replace(s.id, '-', ''), 1, 8)
                                                    ),
                                                    16,
                                                    10
                                                ) as decimal(20, 0)
                                            ) - 122192928000000000
                                        ) / 10000000.0
                                    ),
                                    interval 9 hour
                                ) between timestamp('2010-01-01 00:00:00') and sb.installed_at
                                    then date_add(
                                    from_unixtime(
                                        (
                                            cast(
                                                conv(
                                                    concat(
                                                        substring(replace(s.id, '-', ''), 14, 3),
                                                        substring(replace(s.id, '-', ''), 9, 4),
                                                        substring(replace(s.id, '-', ''), 1, 8)
                                                    ),
                                                    16,
                                                    10
                                                ) as decimal(20, 0)
                                            ) - 122192928000000000
                                        ) / 10000000.0
                                    ),
                                    interval 9 hour
                                )
                                else timestamp('1000-01-01 00:00:00')
                            end
                        )
                    else s.created_date
                end
            ) as first_seen_at
        from schedule s
                 cross join schedule_backfill sb
        group by s.member_id
    ),
    observed_activity as (
        select member_id, min(first_seen_at) as first_seen_at
        from (
                 select member_id, first_seen_at
                 from inferred_schedule_activity

                 union all

                 select member_id, cast(min(duty_date) as datetime) as first_seen_at
                 from duty
                 where duty_date is not null
                 group by member_id

                 union all

                 select member_id, min(created_date) as first_seen_at
                 from member_social_account
                 group by member_id

                 union all

                 select member_id, min(created_date) as first_seen_at
                 from friends
                 group by member_id

                 union all

                 select friend_id as member_id, min(created_date) as first_seen_at
                 from friends
                 group by friend_id

                 union all

                 select from_member_id as member_id, min(created_date) as first_seen_at
                 from friend_requests
                 group by from_member_id

                 union all

                 select to_member_id as member_id, min(created_date) as first_seen_at
                 from friend_requests
                 group by to_member_id

                 union all

                 select manager_id as member_id, min(created_date) as first_seen_at
                 from member_manager
                 group by manager_id

                 union all

                 select managed_id as member_id, min(created_date) as first_seen_at
                 from member_manager
                 group by managed_id
             ) candidates
        where first_seen_at is not null
        group by member_id
    )
update member m
    join observed_activity oa on oa.member_id = m.id
set m.created_date = least(m.created_date, oa.first_seen_at)
where oa.first_seen_at < m.created_date;
