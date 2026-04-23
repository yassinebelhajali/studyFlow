import re
import subprocess

with open(r'c:\Users\anoth\Desktop\studyFlow\lib\home.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

result = subprocess.run(['dart', 'analyze', 'lib/home.dart'], capture_output=True, text=True, shell=True)

for line in result.stdout.split('\n'):
    if 'const_eval_method_invocation' in line or 'invalid_constant' in line or 'unnecessary_const' in line:
        match = re.search(r'home\.dart:(\d+):', line)
        if match:
            line_num = int(match.group(1)) - 1
            
            # If the line itself has const, remove it
            if re.search(r'\bconst\s+', lines[line_num]):
                lines[line_num] = re.sub(r'\bconst\s+', '', lines[line_num])
                print(f"Fixed const at line {line_num + 1}")
            else:
                # Look upwards for the closest const keyword
                for i in range(line_num, max(-1, line_num - 20), -1):
                    if re.search(r'\bconst\s+', lines[i]):
                        lines[i] = re.sub(r'\bconst\s+', '', lines[i])
                        print(f"Fixed const upwards at line {i + 1} for error at {line_num + 1}")
                        break

with open(r'c:\Users\anoth\Desktop\studyFlow\lib\home.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)
