; Create custom rules for particular cases, like this one, when bracker matchup
; pattern should be closed with plain bracket, but not with last line.
; filetype = { 'query', 'scheme', 'commonlisp' }

(todo_item6
    (unordered_list6_prefix) @NeorgTodoItem6
    state:
        [
            (todo_item_undone) @NeorgTodoItem6Undone
            (todo_item_pending) @NeorgTodoItem6Pending
            (todo_item_done) @NeorgTodoItem6Done
            (todo_item_on_hold) @NeorgTodoItem6OnHold
            (todo_item_cancelled) @NeorgTodoItem6Cancelled
            (todo_item_urgent) @NeorgTodoItem6Urgent
            (todo_item_uncertain) @NeorgTodoItem6Uncertain
            (todo_item_recurring) @NeorgTodoItem6Recurring
        ]
    content:
        (paragraph) @NeorgTodoItem6Content)

; vim: ft=query
