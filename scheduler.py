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


def run_scheduler_once():
    """서버 시작 시 한 번 실행되는 스케줄러 함수"""
    print("서버 시작 시 스케줄러 즉시 실행")
    try:
        # daily_metrics.py에서 경제 지표 수집 함수 호출
        from daily_metrics import collect_economic_calendar

        print("경제 지표 데이터 수집 시작...")
        collect_economic_calendar()
        print("초기 스케줄러 작업 완료")
    except Exception as e:
        print(f"초기 스케줄러 실행 중 오류 발생: {e}")


if __name__ == "__main__":
    # print("데이터 수집 스케줄러 시작...")
    run_scheduler()
