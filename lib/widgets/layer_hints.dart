/// 조절 슬라이더/토글에 붙는 "이렇게 하면 이런 게 좋아져요" 식 안내 문구.
/// 기능 설명이 아니라 조정 결과(체감)를 알려준다. 라벨로 매칭.
String layerHint(String label) {
  final l = label.trim();
  if (l.contains('Sub')) return '올릴수록 더 깊고 묵직하게 감싸줘요';
  if (l.contains('Air')) return '올릴수록 위가 트여 공기감·투명함이 살아나요';
  if (l.contains('Main')) return '올릴수록 드론이 더 꽉 차고 두꺼워져요';
  if (l.contains('움직임')) return '느릴수록 잔잔하고, 빠를수록 살짝 일렁여요';
  if (l.contains('스테레오')) return '넓힐수록 공간감이 커지고 감싸는 느낌이 강해져요';
  if (l.contains('비트')) return '낮출수록 깊은 이완·졸림, 높일수록 또렷한 집중 (이어폰 필수)';
  if (l.contains('펄스 속도')) return '빠를수록 리듬감이 또렷, 느릴수록 숨결처럼 잔잔해져요';
  if (l.contains('펄스 깊이')) return '올릴수록 커졌다 작아지는 맥동이 뚜렷해져요';
  if (l.contains('중심 주파수')) return '전체 분위기의 기준음 · 낮추면 묵직·안정, 높이면 맑아져요';
  if (l.contains('기준 주파수')) return '들리는 톤의 높낮이예요 · 편한 쪽으로 맞추세요';
  if (l.contains('좌우 위치')) return '소리를 왼쪽/오른쪽으로 치우치게 해요';
  if (l.contains('좌우 반전')) return '좌우를 바꿔 느낌을 달리해요';
  if (l.contains('좌우 교차')) return '켜면 소리가 좌우로 천천히 오가요';
  if (l.contains('차임 간격')) return '차임이 울리는 간격이에요';
  if (l.contains('음량')) return '올리면 이 소리가 더 앞으로 나와요';
  if (l == '주파수') return '소리의 색이 달라져요 · 낮을수록 묵직·따뜻, 높을수록 맑고 밝음';
  return '';
}
