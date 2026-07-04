update member m
    join (
        select s.member_id,
               min(s.created_date)                        as oldest_schedule_created_date,
               max(coalesce(s.modified_date, s.created_date)) as latest_schedule_modified_date
        from schedule s
        where s.created_date is not null
        group by s.member_id
    ) schedule_stats
        on schedule_stats.member_id = m.id
set m.created_date  = schedule_stats.oldest_schedule_created_date,
    m.modified_date = coalesce(
        schedule_stats.latest_schedule_modified_date,
        schedule_stats.oldest_schedule_created_date,
        m.modified_date
    );
