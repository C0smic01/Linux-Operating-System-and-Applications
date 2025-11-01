# Homework #3: Shell Script Programming

## Họ và tên: Võ Văn Tùng
## MSSV: 22120409

---

# Script 1: Backup Automation Script (auto_backup.sh)
## Cách sử dụng
### Cơ bản
```bash
./auto_backup.sh <thư_mục_nguồn> <thư_mục_backup> <số_backup_tối_đa>
```

### Với Bonus Features
```bash
./auto_backup.sh <thư_mục_nguồn> <thư_mục_backup> <số_backup_tối_đa> [options]
```

## Tham số
- `thư_mục_nguồn`: Thư mục cần backup (ví dụ: /home/projects)
- `thư_mục_backup`: Thư mục đích để lưu backup (ví dụ: /mnt/backup)
- `số_backup_tối_đa`: Số lượng backup tối đa cần giữ lại (ví dụ: 5)

## Tùy chọn Bonus
- `-e, --email EMAIL`: Gửi email thông báo kết quả backup
- `-x, --exclude PATTERN`: Loại trừ file/thư mục khỏi backup (có thể dùng nhiều lần)

## Ví dụ
### Cơ bản
```bash
# Backup đơn giản
./auto_backup.sh /home/projects /mnt/backup 5
```

### Với email notification (Bonus)
```bash
# Backup và gửi email thông báo
./auto_backup.sh /home/projects /mnt/backup 5 --email admin@example.com
```

### Với exclude patterns (Bonus)
```bash
# Backup và loại trừ file log
./auto_backup.sh /home/projects /mnt/backup 5 --exclude "*.log"

# Loại trừ nhiều pattern
./auto_backup.sh /home/projects /mnt/backup 5 \
    --exclude "*.log" \
    --exclude "*.tmp" \
    --exclude "node_modules/" \
    --exclude "cache/"
```

### Kết hợp cả email và exclude (Bonus)
```bash
./auto_backup.sh /home/projects /mnt/backup 5 \
    -e admin@example.com \
    -x "*.log" \
    -x "temp/" \
    -x "*.cache"
```

## Giả định
- Thư mục nguồn phải tồn tại trước khi chạy script
- Người dùng có quyền ghi vào thư mục đích
- Đủ dung lượng đĩa để lưu trữ backup
- Các lệnh cần thiết (tar, ls, rm, date) đã được cài đặt
- Để sử dụng tính năng email, cần cài đặt mailutils: `sudo apt install mailutils`

## Yêu cầu hệ thống
- Bash shell
- Lệnh tar, ls, rm, date, echo phải có sẵn
- Quyền thực thi script: `chmod +x auto_backup.sh`
- (Bonus) mailutils hoặc mailx để gửi email

---

# Script 2: Log File Analysis and Alerting (log_monitor.sh)
## Cách sử dụng

### Cơ bản
```bash
./log_monitor.sh <file_log> [số_dòng]
```

### Với Bonus Features
```bash
./log_monitor.sh <file_log> [số_dòng] [options]
```

## Tham số
- `file_log`: Đường dẫn đến file log cần phân tích (bắt buộc)
- `số_dòng`: Số dòng cuối cùng cần quét (tùy chọn, mặc định: 1000)

## Tùy chọn Bonus
- `-e, --email EMAIL`: Gửi email cảnh báo khi vượt ngưỡng
- `-k, --keywords "KW1 KW2"`: Các từ khóa cần giám sát (mặc định: "ERROR WARNING")
- `-t, --threshold NUM`: Ngưỡng cảnh báo cho ERROR (mặc định: 10)

## Ví dụ
### Cơ bản
```bash
# Phân tích 1000 dòng cuối (mặc định)
./log_monitor.sh /var/log/app.log

# Phân tích 2000 dòng cuối
./log_monitor.sh /var/log/app.log 2000
```

### Với Email notification (Bonus)
```bash
# Gửi email khi vượt ngưỡng
./log_monitor.sh /var/log/app.log 2000 --email admin@example.com

# Tùy chỉnh ngưỡng
./log_monitor.sh /var/log/app.log 2000 -e admin@example.com -t 5
```

### Với Custom keywords (Bonus)
```bash
# Giám sát các từ khóa khác
./log_monitor.sh /var/log/app.log 2000 --keywords "ERROR CRITICAL FATAL"

# Giám sát từ khóa tùy chỉnh và gửi email
./log_monitor.sh /var/log/app.log 2000 \
    -k "ERROR WARNING CRITICAL" \
    -e admin@example.com \
    -t 15
```

### Ví dụ bonus
```bash
# Phân tích system log với cấu hình tùy chỉnh
./log_monitor.sh /var/log/syslog 5000 \
    --keywords "ERROR FATAL PANIC" \
    --email sysadmin@example.com \
    --threshold 3
```

## Giả định
- File log phải có quyền đọc
- Các dòng log chứa từ khóa cần tìm (viết hoa)
- Timestamp nằm ở hai cột đầu tiên của mỗi dòng log
- Định dạng timestamp: YYYY-MM-DD HH:MM:SS
- Để sử dụng tính năng email, cần cài đặt mailutils: `sudo apt install mailutils`

## Yêu cầu hệ thống
- Bash shell
- Lệnh grep, tail, wc, awk, echo, sed phải có sẵn
- Quyền thực thi script: `chmod +x log_monitor.sh`
- (Bonus) mailutils hoặc mailx để gửi email