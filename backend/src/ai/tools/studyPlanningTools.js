const { randomUUID } = require('node:crypto');

function createStudyPlanningTools(store) {
  return [
    {
      name: 'build_study_plan',
      description:
        'Create a structured study plan for a subject, exam, homework, revision session, or day plan and save it to the user tasks.',
      inputSchema: {
        type: 'object',
        properties: {
          goal: 'required string describing what the student needs to accomplish',
          availableMinutes: 'optional integer from 15 to 600',
          priority: 'optional one of low, normal, high',
          subject: 'optional subject name, defaults to General',
        },
      },
      validateInput(input) {
        const goal = typeof input.goal === 'string' ? input.goal.trim() : '';
        if (!goal) {
          return { ok: false, error: 'goal is required for build_study_plan' };
        }

        const availableMinutes =
          input.availableMinutes === undefined || input.availableMinutes === null
            ? 90
            : Number(input.availableMinutes);
        if (
          !Number.isInteger(availableMinutes) ||
          availableMinutes < 15 ||
          availableMinutes > 600
        ) {
          return {
            ok: false,
            error: 'availableMinutes must be an integer from 15 to 600',
          };
        }

        const priority = typeof input.priority === 'string' ? input.priority : 'normal';
        if (!['low', 'normal', 'high'].includes(priority)) {
          return { ok: false, error: 'priority must be low, normal, or high' };
        }

        return {
          ok: true,
          value: {
            goal: goal.slice(0, 240),
            availableMinutes,
            priority,
            subject: typeof input.subject === 'string' ? input.subject.trim() : 'General',
          },
        };
      },
      async execute(input, { userId }) {
        const blockCount = Math.max(1, Math.floor(input.availableMinutes / 30));
        const focusBlocks = Array.from({ length: Math.min(blockCount, 8) }, (_item, index) => ({
          label: `Focus block ${index + 1}`,
          minutes: 25,
          breakMinutes: index === blockCount - 1 ? 0 : 5,
          task:
            index === 0
              ? 'Clarify the target outcome and collect materials'
              : index === blockCount - 1
                ? 'Review, test recall, and list remaining gaps'
                : 'Work through the highest-value exercises or notes',
        }));

        const now = new Date();
        await store.addTasks(
          userId,
          focusBlocks.map((block, index) => ({
            id: `task-${randomUUID()}`,
            title: `${input.goal}: ${block.label}`,
            subject: input.subject || 'Study Plan',
            dueAt: new Date(now.getTime() + (index + 1) * 3600000).toISOString(),
            priority: input.priority === 'normal' ? 'medium' : input.priority,
          })),
        );

        return {
          success: true,
          summary: `Created and saved study plan for "${input.goal}" with ${focusBlocks.length} focus blocks.`,
          data: {
            goal: input.goal,
            priority: input.priority,
            availableMinutes: input.availableMinutes,
            focusBlocks,
          },
        };
      },
    },
    {
      name: 'add_tasks',
      description: 'Add one or more tasks to the user tasks list.',
      inputSchema: {
        type: 'object',
        properties: {
          tasks: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                title: 'string: task title',
                subject: 'string: subject name',
                dueAt: 'string: HH:mm or ISO-like format',
              }
            }
          }
        }
      },
      validateInput(input) {
        if (!Array.isArray(input.tasks) || input.tasks.length === 0) {
          return { ok: false, error: 'tasks array is required and cannot be empty' };
        }
        return { ok: true, value: input };
      },
      async execute(input, { userId }) {
        const now = new Date();
        const dateStr = now.toISOString().split('T')[0];
        await store.addTasks(
          userId,
          input.tasks.map((task) => {
            let dueAt = task.dueAt || '18:00';
            if (dueAt.includes(':') && !dueAt.includes('-')) {
              const [hours, minutes] = dueAt.split(':').map(Number);
              dueAt = new Date(
                Date.UTC(
                  now.getUTCFullYear(),
                  now.getUTCMonth(),
                  now.getUTCDate(),
                  hours,
                  minutes,
                ),
              ).toISOString();
            }
            return {
              id: `task-${randomUUID()}`,
              title: task.title,
              subject: task.subject || 'General',
              dueAt,
              priority: 'medium',
            };
          }),
        );

        return {
          success: true,
          summary: `Successfully added ${input.tasks.length} task(s) to your list.`,
          data: { count: input.tasks.length },
        };
      }
    }
  ];
}

module.exports = {
  createStudyPlanningTools,
};
