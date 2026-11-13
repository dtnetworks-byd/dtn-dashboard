# DT Networks 서비스 대시보드 (Svelte)

Svelte + Vite 로 만든 정적 사이트입니다. GitHub Pages 에 올리고, DB · 로그인은 Supabase 를 씁니다.

## 화면
- **대시보드**: 입고대수·매출 요약 카드, 매출 캘린더(일매출/주매출), 유형별 추이 차트(종류: 누적 막대/묶음 막대/선/영역/도넛, 단위: 일/주/월), 항목별 평균 통계
- **브랜드별 매출**: 브랜드별 매출 카드(비중·일평균·대당 매출), 브랜드별 추이 차트, 브랜드·지점별 표. 기간 필터만 적용
- **프로모션 · 리콜**: 수시로 추가한 프로모션(윈터타이어 패키지 등)·리콜 항목의 누적, 기간, 상태, 지점별 수치와 추이
- **콜 수락율**: 수락 콜 합계 ÷ 인입 콜 합계, 추이 차트, 월별·지점별 표
- **매출 캘린더**: 월 매출·일평균·주평균·최고 매출일 카드 + 달력
- **입력 · 수정** (관리자·입력 담당): 하루치 입력 폼과 입력 내역(수정·삭제)
- **엑셀 입력** (관리자·입력 담당): 지점 × 월 표. 직접 입력, 엑셀 범위 붙여넣기, 엑셀 파일 가져오기·내보내기
- **관리자** (관리자만): 프로모션·리콜 / 기본 항목 / 브랜드·지점(비활성화 포함) / 계정·권한

## 프로모션 · 리콜
관리자 페이지에서 종류(프로모션/리콜), 이름, 대상 브랜드(전체 또는 특정 브랜드 전용), 시작일, 종료일(선택), 단위를 정해 추가합니다.
- 추가하면 해당 브랜드 지점의 입력 화면과 엑셀 입력 표에 그 기간 동안 입력 칸이 생깁니다
- "오늘로 종료", "중지", "다시 진행"으로 언제든 끄고 켤 수 있고, 입력해 둔 수치는 남습니다
- 수치는 입고대수·매출 합계에 더해지지 않고 "프로모션 · 리콜" 화면에서 따로 집계됩니다

## 계정과 권한
| 권한 | 조회 | 입력·수정·엑셀 | 관리자 페이지 |
|---|---|---|---|
| 관리자(admin) | O | O | O |
| 입력 담당(editor) | O | O | X |
| 조회 전용(viewer) | O | X | X |

- 권한은 화면에서만 가리는 것이 아니라 DB 보안 정책(RLS)으로도 막혀 있습니다
- 새 사람은 로그인 화면의 "계정 신청"으로 가입 → 이메일 확인 → 로그인하면 자동으로 열람 신청이 남고,
  관리자가 관리자 페이지 > 계정·권한에서 권한을 골라 승인합니다. 승인 전에는 아무 데이터도 볼 수 없습니다
- 첫 관리자만 `schema.sql` 맨 아래 9번 SQL 로 직접 등록합니다

## 엑셀 가져오기 · 내보내기
- **이 달 내보내기**: 선택한 지점·달의 표를 .xlsx 로 저장(빈 날짜 포함 → 입력 양식으로 사용 가능)
- **전체 내보내기**: 선택한 지점의 전체 기간을 .xlsx 로 저장(백업용)
- **엑셀 가져오기**: 같은 양식의 .xlsx 를 읽어 선택한 지점에 저장
  - 첫 행은 `날짜` + 항목명, 둘째 행부터 날짜와 값. 열은 **머리글 이름**으로 맞추므로 순서가 달라도 됩니다
  - 날짜는 엑셀 날짜 셀, `2026-11-03`, `2026.11.03`, `2026/11/03` 모두 인식
  - 저장 전에 읽은 범위·칸 수·무시된 열을 보여 주고 확인을 받습니다
  - 파일에 없는 날짜와 빈 칸은 건드리지 않습니다(가져오기로는 삭제되지 않음)

## 설치
### 1. Supabase
1. https://supabase.com 에서 프로젝트 생성 → **SQL Editor** 에 `schema.sql` 전체를 붙여넣고 실행 (여러 번 실행해도 안전)
2. **Authentication > Users > Add user** 로 본인 계정 생성
3. SQL Editor 에서 본인을 첫 관리자로 등록:
   ```sql
   insert into members (user_id, email, role)
   select id, email, 'admin' from auth.users where email = '본인이메일'
   on conflict (user_id) do update set role = 'admin', email = excluded.email;
   ```
4. **Settings > API** 의 Project URL 과 anon(publishable) key 를 `config.js` 에 입력
   (`service_role` / secret 키는 절대 넣지 마세요)
5. 직원이 "계정 신청"으로 직접 가입하게 하려면 Authentication 의 신규 가입(Allow new users to sign up)을 켜 둡니다.
   끄면 관리자가 Supabase 에서 계정을 만들어 주고, 그 계정이 처음 로그인할 때 열람 신청이 남습니다

### 2. GitHub Pages — 두 가지 방법 중 하나
**A. 빌드된 파일만 올리기 (간단)**
`dtn-dashboard-site.zip` 을 풀어 나온 `index.html`, `config.js`, `assets/`, `.github/` 를 저장소에 그대로 올리고,
Settings > Pages > Source 를 "Deploy from a branch" (main / root) 로 설정합니다. 설정 파일은 `config.js` 입니다.

**B. 소스를 올리고 자동 빌드 (수정할 계획이 있을 때)**
`dtn-dashboard-src.zip` 의 내용을 저장소에 올리고, Settings > Pages > Source 를 "GitHub Actions" 로 설정합니다.
main 에 올릴 때마다 `.github/workflows/deploy.yml` 이 빌드·배포합니다. 설정 파일은 `public/config.js` 입니다.

### 로컬에서 실행 (B 방식)
```
npm install
npm run dev      # 개발 서버
npm run build    # dist/ 에 결과물 생성
```

## 일시정지 방지
Supabase 무료 프로젝트는 1주일 무활동 시 일시정지됩니다. `.github/workflows/keepalive.yml` 이 매일 한 번 `keepalive` 테이블을 조회합니다.
GitHub 는 저장소에 60일간 변경이 없으면 예약 실행을 꺼 두니, 안내 메일이 오면 Actions 탭에서 다시 켜 주세요.

## 보안 구조
- 실적 데이터는 저장소가 아니라 Supabase DB 에만 있습니다
- 비밀번호는 Supabase Auth 가 해시로 저장하고, 통신은 HTTPS 입니다
- 모든 테이블에 RLS 가 걸려 있어 승인된 계정만 읽을 수 있고, 쓰기는 권한(관리자/입력 담당)에 따라 DB 에서 막힙니다
- `config.js` 의 anon 키는 공개용 키라 노출되어도 RLS 를 통과하지 못합니다

## 코드 구조
| 파일 | 역할 |
|---|---|
| `src/core.js` | 집계·검증·엑셀 행 변환 (순수 함수) |
| `src/backend.js` | Supabase / 데모(localStorage) 데이터 계층 |
| `src/xlsx.js` | 엑셀 파일 읽기·쓰기 (exceljs, 버튼을 누를 때만 로드) |
| `src/*.svelte` | 화면 컴포넌트 |
| `public/config.js` | Supabase 주소·키 |
| `schema.sql` | DB 테이블 + 보안 정책 + 초기 데이터 |
