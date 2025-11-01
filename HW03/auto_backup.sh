#!/bin/bash

# Hiển thị hướng dẫn sử dụng
show_usage() {
    cat << EOF
Cách dùng: $0 <thư_mục_nguồn> <thư_mục_backup> <số_backup_tối_đa> [options]

Tham số bắt buộc:
  thư_mục_nguồn       : Thư mục cần backup
  thư_mục_backup      : Thư mục đích lưu backup
  số_backup_tối_đa    : Số lượng backup tối đa giữ lại

Tùy chọn (Bonus):
  -e, --email EMAIL   : Gửi email thông báo đến địa chỉ này
  -x, --exclude PATTERN : Loại trừ file/thư mục (có thể dùng nhiều lần)
                         Ví dụ: --exclude "*.log" --exclude "temp/"

Ví dụ:
  $0 /home/projects /mnt/backup 5
  $0 /home/projects /mnt/backup 5 --email admin@example.com
  $0 /home/projects /mnt/backup 5 --exclude "*.log" --exclude "node_modules/"
  $0 /home/projects /mnt/backup 5 -e admin@example.com -x "*.tmp" -x "cache/"

EOF
    exit 1
}

# Ghi log
log_message() {
    local message="$1"
    local log_file="$HOME/backup.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$log_file"
}

# kiểm tra thư mục có tồn tại không
check_directory() {
    local dir="$1"
    local dir_type="$2"
    
    if [ ! -d "$dir" ]; then
        log_message "LỖI: Thư mục $dir_type '$dir' không tồn tại"
        exit 1
    fi
}

# kiểm tra quyền ghi vào thư mục
check_writable() {
    local dir="$1"
    
    if [ ! -w "$dir" ]; then
        log_message "LỖI: Thư mục đích '$dir' không có quyền ghi"
        exit 1
    fi
}

# gửi email thông báo
send_email() {
    local email_address="$1"
    local subject="$2"
    local message="$3"
    
    # Kiểm tra xem mailx hoặc mail có được cài đặt không
    if command -v mailx &> /dev/null; then
        echo "$message" | mailx -s "$subject" "$email_address"
        log_message "THÔNG BÁO: Đã gửi email thông báo đến $email_address"
    elif command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$email_address"
        log_message "THÔNG BÁO: Đã gửi email thông báo đến $email_address"
    else
        log_message "CẢNH BÁO: Không thể gửi email (mailx/mail chưa được cài đặt)"
        log_message "HƯỚNG DẪN: Cài đặt bằng lệnh: sudo apt install mailutils"
    fi
}

# Hàm tạo backup với tùy chọn loại trừ (Bonus)
create_backup() {
    local source="$1"
    local destination="$2"
    shift 2
    local exclude_patterns=("$@")
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="backup_${timestamp}.tar.gz"
    local backup_path="${destination}/${backup_name}"
    
    log_message "THÔNG BÁO: Bắt đầu backup '$source'"
    
    # Tạo chuỗi exclude cho tar
    local exclude_options=""
    for pattern in "${exclude_patterns[@]}"; do
        if [ -n "$pattern" ]; then
            exclude_options="$exclude_options --exclude=$pattern"
            log_message "THÔNG BÁO: Loại trừ pattern: $pattern"
        fi
    done
    
    # Tạo file nén với exclude options
    if tar -czf "$backup_path" $exclude_options -C "$(dirname "$source")" "$(basename "$source")" 2>/dev/null; then
        local file_size=$(du -h "$backup_path" | cut -f1)
        log_message "THÀNH CÔNG: Backup được tạo thành công: $backup_name (Kích thước: $file_size)"
        echo "$backup_name"
        return 0
    else
        log_message "LỖI: Không thể tạo file backup"
        return 1
    fi
}

# Hàm xoay vòng backup (chỉ giữ lại N backup mới nhất)
rotate_backups() {
    local backup_dir="$1"
    local max_backups="$2"
    
    # Đếm số backup hiện có
    local backup_count=$(ls -1 "$backup_dir"/backup_*.tar.gz 2>/dev/null | wc -l)
    
    if [ "$backup_count" -gt "$max_backups" ]; then
        log_message "THÔNG BÁO: Tìm thấy $backup_count backups, chỉ giữ lại $max_backups backup mới nhất"
        
        # Lấy danh sách backup cũ cần xóa (sắp xếp theo thời gian, cũ nhất trước)
        local files_to_delete=$(ls -1t "$backup_dir"/backup_*.tar.gz | tail -n +$((max_backups + 1)))
        
        # Xóa backup cũ
        for file in $files_to_delete; do
            if rm "$file" 2>/dev/null; then
                log_message "THÔNG BÁO: Đã xóa backup cũ: $(basename "$file")"
            else
                log_message "LỖI: Không thể xóa backup: $(basename "$file")"
            fi
        done
    else
        log_message "THÔNG BÁO: Số lượng backup hiện tại ($backup_count) trong giới hạn ($max_backups)"
    fi
}

main() {
    # Kiểm tra số lượng tham số tối thiểu
    if [ $# -lt 3 ]; then
        show_usage
    fi
    
    # Gán tham số bắt buộc
    local source_dir="$1"
    local backup_dir="$2"
    local max_backups="$3"
    shift 3
    
    # Kiểm tra max_backups phải là số
    if ! [[ "$max_backups" =~ ^[0-9]+$ ]] || [ "$max_backups" -lt 1 ]; then
        echo "LỖI: số_backup_tối_đa phải là số nguyên dương"
        exit 1
    fi
    
    local email_address=""
    local exclude_patterns=()
    
    # Xử lý các tùy chọn bonus
    while [ $# -gt 0 ]; do
        case "$1" in
            -e|--email)
                email_address="$2"
                shift 2
                ;;
            -x|--exclude)
                exclude_patterns+=("$2")
                shift 2
                ;;
            *)
                echo "LỖI: Tùy chọn không hợp lệ: $1"
                show_usage
                ;;
        esac
    done
    
    # Ghi thời gian bắt đầu
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    log_message "========================================="
    log_message "THÔNG BÁO: Bắt đầu quá trình backup"
    
    # Kiểm tra thư mục nguồn
    check_directory "$source_dir" "nguồn"
    
    # Kiểm tra và tạo thư mục backup nếu cần
    if [ ! -d "$backup_dir" ]; then
        log_message "THÔNG BÁO: Tạo thư mục backup: $backup_dir"
        mkdir -p "$backup_dir" || {
            log_message "LỖI: Không thể tạo thư mục backup"
            
            # Gửi email thông báo lỗi (nếu có)
            if [ -n "$email_address" ]; then
                send_email "$email_address" \
                    "Backup Failed: $(hostname)" \
                    "Quá trình backup thất bại lúc $start_time. Không thể tạo thư mục backup."
            fi
            
            exit 1
        }
    fi
    
    # Kiểm tra quyền ghi vào thư mục backup
    check_writable "$backup_dir"
    
    # Tạo backup
    if backup_file=$(create_backup "$source_dir" "$backup_dir" "${exclude_patterns[@]}"); then
        # Xoay vòng backup
        rotate_backups "$backup_dir" "$max_backups"
        
        # Ghi thời gian kết thúc
        local end_time=$(date '+%Y-%m-%d %H:%M:%S')
        log_message "THÔNG BÁO: Quá trình backup hoàn thành thành công"
        log_message "THÔNG BÁO: Thời gian bắt đầu: $start_time"
        log_message "THÔNG BÁO: Thời gian kết thúc: $end_time"
        log_message "========================================="
        
        # Gửi email thông báo thành công (Bonus)
        if [ -n "$email_address" ]; then
            local backup_count=$(ls -1 "$backup_dir"/backup_*.tar.gz 2>/dev/null | wc -l)
            local email_body="Quá trình backup hoàn thành thành công!

Chi tiết:
- Máy chủ: $(hostname)
- Thư mục nguồn: $source_dir
- Thư mục đích: $backup_dir
- File backup: $backup_file
- Thời gian bắt đầu: $start_time
- Thời gian kết thúc: $end_time
- Tổng số backup hiện có: $backup_count
- Số backup tối đa: $max_backups"

            if [ ${#exclude_patterns[@]} -gt 0 ]; then
                email_body="$email_body

Các pattern được loại trừ:"
                for pattern in "${exclude_patterns[@]}"; do
                    email_body="$email_body
  - $pattern"
                done
            fi
            
            send_email "$email_address" \
                "Backup Success: $(hostname)" \
                "$email_body"
        fi
        
        exit 0
    else
        local end_time=$(date '+%Y-%m-%d %H:%M:%S')
        log_message "LỖI: Quá trình backup thất bại"
        log_message "THÔNG BÁO: Thời gian bắt đầu: $start_time"
        log_message "THÔNG BÁO: Thời gian kết thúc: $end_time"
        log_message "========================================="
        
        # Gửi email thông báo lỗi (Bonus)
        if [ -n "$email_address" ]; then
            send_email "$email_address" \
                "Backup Failed: $(hostname)" \
                "Quá trình backup thất bại!

Chi tiết:
- Máy chủ: $(hostname)
- Thư mục nguồn: $source_dir
- Thư mục đích: $backup_dir
- Thời gian bắt đầu: $start_time
- Thời gian kết thúc: $end_time

Vui lòng kiểm tra log tại: $HOME/backup.log"
        fi
        
        exit 1
    fi
}

main "$@"