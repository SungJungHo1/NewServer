import pandas as pd
import numpy as np


def analyze_excel_file():
    """Excel 파일을 분석하고 중복 제거를 수행하는 함수"""

    # 파일 읽기
    print("Excel 파일을 읽는 중...")
    try:
        df = pd.read_excel("cleaned_output_robust.xlsx")
        print(f"파일 읽기 성공! 총 {len(df)}행, {len(df.columns)}열")

        # 상위 10행 출력
        print("\n=== 상위 10행 데이터 ===")
        print(df.head(10))

        # 컬럼 정보 출력
        print(f"\n=== 컬럼 정보 ===")
        print(f"컬럼명: {list(df.columns)}")
        print(f"데이터 타입:")
        print(df.dtypes)

        # 각 컬럼의 고유값 개수 확인
        print(f"\n=== 각 컬럼의 고유값 개수 ===")
        for col in df.columns:
            unique_count = df[col].nunique()
            total_count = len(df)
            print(
                f"{col}: {unique_count}/{total_count} ({unique_count/total_count*100:.2f}%)"
            )

        return df

    except Exception as e:
        print(f"파일 읽기 오류: {e}")
        return None


def remove_duplicates_by_name(df):
    """이름 컬럼을 기준으로 중복 제거"""

    print(f"\n=== 이름 컬럼 기준 중복 제거 ===")
    print(f"중복 제거 전 총 행 수: {len(df)}")

    # 이름 컬럼에서 중복 확인
    duplicates = df.duplicated(subset=["이름"], keep="first")
    duplicate_count = duplicates.sum()

    print(f"중복 행 수: {duplicate_count}")
    print(f"중복 비율: {duplicate_count/len(df)*100:.2f}%")

    if duplicate_count > 0:
        # 중복 제거
        df_cleaned = df.drop_duplicates(subset=["이름"], keep="first")
        print(f"중복 제거 후 행 수: {len(df_cleaned)}")
        print(f"제거된 행 수: {len(df) - len(df_cleaned)}")

        # 결과 저장
        output_filename = "cleaned_output_no_duplicates_by_name.xlsx"
        df_cleaned.to_excel(output_filename, index=False)
        print(f"결과가 {output_filename}에 저장되었습니다.")

        # 중복된 이름들 확인 (샘플)
        duplicate_names = df[df.duplicated(subset=["이름"], keep=False)][
            "이름"
        ].value_counts()
        print(f"\n=== 중복된 이름들 (상위 10개) ===")
        print(duplicate_names.head(10))

        return df_cleaned
    else:
        print("중복된 이름이 없습니다.")
        return df


def main():
    print("Excel 파일 분석 및 중복 제거 시작...")

    # 파일 분석
    df = analyze_excel_file()

    if df is not None:
        # 이름 기준 중복 제거
        cleaned_df = remove_duplicates_by_name(df)

        print(f"\n=== 최종 결과 ===")
        print(f"원본 행 수: {len(df)}")
        print(f"정리 후 행 수: {len(cleaned_df)}")
        print(f"제거된 행 수: {len(df) - len(cleaned_df)}")


if __name__ == "__main__":
    main()
