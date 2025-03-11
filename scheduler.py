import schedule
import time
from datetime import datetime
from DB_findKorea import get_main_indicators
from DB_findKorea import insert_trading_log


def collect_daily_data():
    try:
        # 주요 지표 데이터 수집
        indicators = get_main_indicators()

        # 데이터가 있는 경우에만 처리
        if indicators:
            current_time = int(datetime.now().timestamp())
            # 수집된 데이터를 시스템 계정에 저장
            insert_trading_log("SYSTEM", current_time, 0, len(indicators))
        #     print(f"[{datetime.now()}] 일일 데이터 수집 완료: {len(indicators)}개 지표")
        # else:
        #     print(f"[{datetime.now()}] 수집된 지표 없음")

    except Exception as e:
        # print(f"[{datetime.now()}] 데이터 수집 중 오류 발생: {str(e)}")
        pass


def run_scheduler():
    # 매일 12시에 실행
    schedule.every().day.at("12:00").do(collect_daily_data)

    while True:
        schedule.run_pending()
        time.sleep(60)  # 1분마다 스케줄 체크


if __name__ == "__main__":
    # print("데이터 수집 스케줄러 시작...")
    run_scheduler()
