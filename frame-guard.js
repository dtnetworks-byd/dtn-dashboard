// 클릭재킹 방어: 다른 사이트의 iframe 안에서 열리면 화면을 숨기고 이 사이트로 빠져나감
// (GitHub Pages 는 X-Frame-Options / frame-ancestors 헤더를 못 붙이고, meta 로는 브라우저가 무시하므로 스크립트로 처리)
(function () {
  if (window.top === window.self) return;
  document.documentElement.style.display = 'none';
  try { window.top.location = window.self.location.href; } catch (e) { /* 막히면 숨긴 채로 둠 */ }
})();
