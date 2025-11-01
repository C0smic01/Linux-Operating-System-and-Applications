#!/bin/bash

DEFAULT_LINES=1000
DEFAULT_ERROR_THRESHOLD=10
REPORT_FILE="log_alert_report.txt"
DEFAULT_KEYWORDS="ERROR WARNING"

# Hiển thị hướng dẫn sử dụng
show_usage() {
    cat << EOF
Cách dùng: $0 <file_log> [số_dòng] [options]

Tham số:
  file_log  : Đường dẫn đến file log cần phân tích (bắt buộc)
  số_dòng   : Số dòng cuối cùng cần quét (mặc định: $DEFAULT_LINES)

Tùy chọn (Bonus):
  -e, --email EMAIL        : Gửi email cảnh báo khi vượt ngưỡng
  -k, --keywords "KW1 KW2" : Từ khóa cần giám sát (mặc định: "ERROR WARNING")
  -t, --threshold NUM      : Ngưỡng cảnh báo cho ERROR (mặc định: $DEFAULT_ERROR_THRESHOLD)

Ví dụ:
  $0 /var/log/app.log
  $0 /var/log/app.log 2000
  $0 /var/log/app.log 2000 --email admin@example.com
  $0 /var/log/app.log 2000 -e admin@example.com -t 5
  $0 /var/log/app.log 2000 -k "ERROR CRITICAL FATAL"

EOF
    exit 1
}

# Hàm kiểm tra file log có tồn tại đọc đc không
check_log_file() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        echo "LỖI: File log '$log_file' không tồn tại"
        exit 1
    fi
    
    if [ ! -r "$log_file" ]; then
        echo "LỖI: File log '$log_file' không thể đọc"
        exit 1
    fi
}

# gửi email cảnh báo
send_alert_email() {
    local email_address="$1"
    local subject="$2"
    local message="$3"
    
    # Kiểm tra xem mailx hoặc mail có được cài đặt không
    if command -v mailx &> /dev/null; then
        echo "$message" | mailx -s "$subject" "$email_address"
        echo "THÔNG BÁO: Đã gửi email cảnh báo đến $email_address"
    elif command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$email_address"
        echo "THÔNG BÁO: Đã gửi email cảnh báo đến $email_address"
    else
        echo "CẢNH BÁO: Không thể gửi email (mailx/mail chưa được cài đặt)"
        echo "HƯỚNG DẪN: Cài đặt bằng lệnh: sudo apt-get install mailutils"
    fi
}

# Phân tích file log với từ khóa tùy chỉnh
analyze_log() {
    local log_file="$1"
    local num_lines="$2"
    local keywords="$3"
    local error_threshold="$4"
    local email_address="$5"
    
    echo "Đang phân tích file log: $log_file"
    echo "Quét $num_lines dòng cuối cùng..."
    echo "Từ khóa giám sát: $keywords"
    echo ""
    
    # Lấy N dòng cuối cùng của file log
    local log_content=$(tail -n "$num_lines" "$log_file")
    
    # Tạo pattern regex từ keywords
    local keyword_pattern=$(echo "$keywords" | sed 's/ /|/g')
    
    # Đếm số lượng cho từng keyword
    declare -A keyword_counts
    local total_issues=0
    local error_count=0
    
    for keyword in $keywords; do
        local count=$(echo "$log_content" | grep -c "$keyword")
        keyword_counts[$keyword]=$count
        total_issues=$((total_issues + count))
        
        # Nếu keyword là ERROR thì lưu vào error_count
        if [ "$keyword" = "ERROR" ]; then
            error_count=$count
        fi
    done
    
    # kiểm tra có tìm thấy keyword nào không
    if [ "$total_issues" -eq 0 ]; then
        echo "Không tìm thấy các từ khóa ($keywords) trong $num_lines dòng cuối"
        generate_report "$log_file" "$num_lines" "$keywords" "false" "$error_threshold"
        exit 0
    fi
    
    # Lấy entry gần nhất chứa bất kỳ keyword nào
    local recent_entry=$(echo "$log_content" | grep -E "$keyword_pattern" | tail -n 1)
    local recent_timestamp=$(echo "$recent_entry" | awk '{print $1, $2}')
    
    if [ -z "$recent_timestamp" ]; then
        recent_timestamp="Không tìm thấy"
    fi
    
    # Kiểm tra có cần cảnh báo nghiêm trọng không
    local is_critical="false"
    if [ "$error_count" -gt "$error_threshold" ]; then
        is_critical="true"
    fi
    
    # Tạo báo cáo
    generate_report "$log_file" "$num_lines" "$keywords" "$is_critical" "$error_threshold"
    
    # Hiển thị tóm tắt
    display_summary "$keywords" "$recent_timestamp" "$is_critical" "$error_count" "$error_threshold"
    
    # Gửi email nếu cần (Bonus)
    if [ "$is_critical" = "true" ] && [ -n "$email_address" ]; then
        local email_body="CẢNH BÁO NGHIÊM TRỌNG từ $(hostname)!

File log: $log_file
Số dòng phân tích: $num_lines

Chi tiết:"

        for keyword in $keywords; do
            email_body="$email_body
  - $keyword: ${keyword_counts[$keyword]}"
        done
        
        email_body="$email_body

Timestamp gần nhất: $recent_timestamp
Ngưỡng ERROR: $error_threshold
Số ERROR hiện tại: $error_count

*** YÊU CẦU XỬ LÝ NGAY LẬP TỨC ***

Xem chi tiết tại: $REPORT_FILE"
        
        send_alert_email "$email_address" \
            "CRITICAL ALERT: Log Monitor - $(hostname)" \
            "$email_body"
    fi
}

# Hàm tạo file báo cáo
generate_report() {
    local log_file="$1"
    local num_lines="$2"
    local keywords="$3"
    local is_critical="$4"
    local error_threshold="$5"
    
    # Lấy lại log content để tính toán
    local log_content=$(tail -n "$num_lines" "$log_file")
    
    # Tạo báo cáo
    cat > "$REPORT_FILE" << EOF
=====================================================
                BÁO CÁO PHÂN TÍCH LOG
=====================================================
Báo cáo được tạo: $(date '+%Y-%m-%d %H:%M:%S')
Máy chủ: $(hostname)
File log: $log_file
Số dòng phân tích: $num_lines
Từ khóa giám sát: $keywords
Ngưỡng cảnh báo ERROR: $error_threshold
------------------------------------------------------

TÓM TẮT:
EOF

    # Đếm và ghi từng keyword
    declare -A keyword_counts
    local recent_timestamp="Không có"
    local keyword_pattern=$(echo "$keywords" | sed 's/ /|/g')
    
    for keyword in $keywords; do
        local count=$(echo "$log_content" | grep -c "$keyword")
        keyword_counts[$keyword]=$count
        echo "  - Tổng số $keyword tìm thấy: $count" >> "$REPORT_FILE"
    done
    
    # Lấy timestamp gần nhất
    local recent_entry=$(echo "$log_content" | grep -E "$keyword_pattern" | tail -n 1)
    if [ -n "$recent_entry" ]; then
        recent_timestamp=$(echo "$recent_entry" | awk '{print $1, $2}')
    fi
    
    cat >> "$REPORT_FILE" << EOF
  - Timestamp gần nhất: $recent_timestamp

------------------------------------------------------
EOF

    # Thêm cảnh báo nghiêm trọng nếu cần
    if [ "$is_critical" = "true" ]; then
        cat >> "$REPORT_FILE" << EOF

!!! CẢNH BÁO NGHIÊM TRỌNG !!!
Số lượng ERROR (${keyword_counts[ERROR]}) vượt quá ngưỡng cho phép ($error_threshold)
Cần xử lý ngay!

EOF
    fi
    
    # Thêm top 10 entries gần nhất
    cat >> "$REPORT_FILE" << EOF
TOP 10 ENTRIES GẦN NHẤT:
EOF
    
    echo "$log_content" | grep -E "$keyword_pattern" | tail -n 10 >> "$REPORT_FILE"
    
    cat >> "$REPORT_FILE" << EOF

=====================================================
EOF
    
    echo "Báo cáo đã được lưu vào: $REPORT_FILE"
}

# Hàm hiển thị tóm tắt trên màn hình
display_summary() {
    local keywords="$1"
    local recent_timestamp="$2"
    local is_critical="$3"
    local error_count="$4"
    local error_threshold="$5"
    
    # Lấy lại log content để đếm
    local log_content=$(tail -n "$num_lines" "$log_file")
    
    echo "========================================="
    echo "           TÓM TẮT PHÂN TÍCH"
    echo "========================================="
    
    for keyword in $keywords; do
        local count=$(echo "$log_content" | grep -c "$keyword")
        echo "$keyword tìm thấy: $count"
    done
    
    echo "Gần nhất lúc: $recent_timestamp"
    echo "========================================="
    
    if [ "$is_critical" = "true" ]; then
        echo ""
        echo "*** CẢNH BÁO NGHIÊM TRỌNG ***"
        echo "Số lượng ERROR ($error_count) vượt ngưỡng ($error_threshold)!"
        echo "Cần hành động ngay lập tức!"
        echo ""
    fi
}

main() {
    # Kiểm tra có ít nhất một tham số
    if [ $# -lt 1 ]; then
        show_usage
    fi
    
    # Gán tham số đầu tiên
    local log_file="$1"
    shift
    
    # Giá trị mặc định
    local num_lines="$DEFAULT_LINES"
    local keywords="$DEFAULT_KEYWORDS"
    local error_threshold="$DEFAULT_ERROR_THRESHOLD"
    local email_address=""
    
    # Kiểm tra tham số thứ 2 có phải là số không (số_dòng)
    if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
        num_lines="$1"
        shift
    fi
    
    # Xử lý các tùy chọn bonus
    while [ $# -gt 0 ]; do
        case "$1" in
            -e|--email)
                email_address="$2"
                shift 2
                ;;
            -k|--keywords)
                keywords="$2"
                shift 2
                ;;
            -t|--threshold)
                error_threshold="$2"
                if ! [[ "$error_threshold" =~ ^[0-9]+$ ]] || [ "$error_threshold" -lt 1 ]; then
                    echo "LỖI: threshold phải là số nguyên dương"
                    exit 1
                fi
                shift 2
                ;;
            *)
                echo "LỖI: Tùy chọn không hợp lệ: $1"
                show_usage
                ;;
        esac
    done
    
    # Kiểm tra số_dòng phải là số
    if ! [[ "$num_lines" =~ ^[0-9]+$ ]] || [ "$num_lines" -lt 1 ]; then
        echo "LỖI: số_dòng phải là số nguyên dương"
        exit 1
    fi
    
    # Kiểm tra file log
    check_log_file "$log_file"
    
    # Phân tích file log
    analyze_log "$log_file" "$num_lines" "$keywords" "$error_threshold" "$email_address"
}

main "$@"