import re

filepath = r'c:\Users\anoth\Desktop\studyFlow\lib\home.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

replacements = [
    (r'const Color\(0xFFF5F7FB\)', 'Theme.of(context).scaffoldBackgroundColor'),
    (r'Color\(0xFFF5F7FB\)', 'Theme.of(context).scaffoldBackgroundColor'),
    (r'Color\(0xFF64748B\)', 'Theme.of(context).colorScheme.onSurfaceVariant'),
    (r'const Color\(0xFF0F172A\)', 'Theme.of(context).colorScheme.onSurface'),
    (r'Color\(0xFF1E293B\)', 'Theme.of(context).colorScheme.onSurface'),
    (r'Color\(0xFF334155\)', 'Theme.of(context).colorScheme.onSurface'),
    (r'Color\(0xFF526285\)', 'Theme.of(context).colorScheme.onSurfaceVariant'),
    (r'Color\(0xFF94A3B8\)', 'Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)'),
    (r'Color\(0xFF1A2746\)', 'Theme.of(context).colorScheme.onSurface'),
    (r'Color\(0xFFE2E8F0\)', 'Theme.of(context).colorScheme.outlineVariant'),
    (r'Color\(0xFFD6DEEE\)', 'Theme.of(context).colorScheme.outlineVariant'),
    (r'Color\(0xFFD8E2F7\)', 'Theme.of(context).colorScheme.outlineVariant'),
    (r'Color\(0xFF6366F1\)', 'Theme.of(context).colorScheme.primary'),
    (r'Color\(0xFF3B82F6\)', 'Theme.of(context).colorScheme.primary'),
    (r'Color\(0xFF2563EB\)', 'Theme.of(context).colorScheme.primary'),
    (r'Color\(0xFF1D3E88\)', 'Theme.of(context).colorScheme.primary'),
    (r'Color\(0xFFF8FAFC\)', 'Theme.of(context).scaffoldBackgroundColor'),
    (r'Color\(0xFFFFFFFF\)', 'Theme.of(context).colorScheme.surface'),
    (r'Color\(0xFFE8EEF9\)', 'Theme.of(context).colorScheme.surfaceContainerHighest'),
    (r'Color\(0xFF5E6B87\)', 'Theme.of(context).colorScheme.onSurfaceVariant'),
    (r'Color\(0xFFEF4444\)', 'Theme.of(context).colorScheme.error'),
    (r'Color\(0x14233A70\)', 'Theme.of(context).shadowColor.withValues(alpha: 0.08)'),
    (r'Color\(0xFFE4F3FF\)', 'Theme.of(context).colorScheme.primaryContainer'),
    (r'Color\(0xFFEAE7FF\)', 'Theme.of(context).colorScheme.secondaryContainer'),
    (r'Color\(0xFFFFE8EF\)', 'Theme.of(context).colorScheme.tertiaryContainer'),
    (r'Color\(0x1D304B9D\)', 'Theme.of(context).shadowColor.withValues(alpha: 0.1)'),
    (r'Color\(0xFFBDE9FF\)', 'Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7)'),
    (r'Color\(0xFFD1D6FF\)', 'Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.7)'),
    (r'Color\(0xFFE6D0FF\)', 'Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.7)'),
    (r'Color\(0x0D000000\)', 'Theme.of(context).shadowColor.withValues(alpha: 0.05)'),
    (r'Color\(0xFFCBD5E1\)', 'Theme.of(context).colorScheme.outline'),
    (r'Colors\.white', 'Theme.of(context).colorScheme.surface'),
    (r'Colors\.black', 'Theme.of(context).shadowColor'),
]

for i in range(len(lines)):
    original = lines[i]
    for old, new in replacements:
        lines[i] = re.sub(old, new, lines[i])
    
    # Replace `.withValues(alpha: ).withValues(alpha: ` if there was stacking
    lines[i] = re.sub(r'withOpacity\((.*?)\)', r'withValues(alpha: \1)', lines[i])
    lines[i] = re.sub(r'\.withValues\(alpha: (.*?)\)\.withValues\(alpha: (.*?)\)', r'.withValues(alpha: \1)', lines[i])

    # If the line now contains 'Theme.of', we strip 'const ' from it.
    if 'Theme.of' in lines[i]:
        # Also strip const from the line
        lines[i] = re.sub(r'\bconst\s+', '', lines[i])

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(lines)
