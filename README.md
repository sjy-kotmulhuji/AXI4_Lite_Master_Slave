# AXI4-Lite Master / Slave 설계

> SystemVerilog | Basys3 (Artix-7) | Vivado 2023.1  
> AXI4-Lite 프로토콜 기반 Master·Slave IP 직접 설계 및 시뮬레이션 검증

---

## 📌 프로젝트 개요

AXI4-Lite 프로토콜의 동작 원리를 이해하고, Master와 Slave를 각각 FSM 기반으로 직접 설계하여 Write/Read 트랜잭션을 검증한 프로젝트입니다.  
이후 MicroBlaze SoC 시스템에 GPIO, FND IP를 연결하여 버튼 입력 기반 카운터를 FPGA 보드에서 동작시켰습니다.

| 항목 | 내용 |
|------|------|
| **프로토콜** | AXI4-Lite |
| **설계 언어** | SystemVerilog, C |
| **툴** | Vivado 2023.1, Vitis |
| **보드** | Basys3 (Xilinx Artix-7) |

---

## 📚 AXI 개념 정리

### AXI란?

AMBA Bus 프로토콜 중 하나로, SoC 내부에서 CPU와 주변장치 간 고속 통신을 위한 표준 인터페이스입니다.  
흔히 "버스"라고 오해하기 쉽지만, AXI는 **Point-to-Point 방식의 인터페이스/프로토콜**입니다.

- Bus: 모든 Peripheral에 주소·데이터를 broadcasting → Chip Select 필요
- AXI: 통신 대상 Slave에만 직접 전달 → broadcasting 없음, switch가 Mux/Decoder 역할 담당

### 채널 구조

AXI4-Lite는 5개의 독립 채널로 구성됩니다.

| 채널 | 방향 | 설명 |
|------|------|------|
| AW | Master → Slave | Write Address |
| W  | Master → Slave | Write Data |
| B  | Slave → Master | Write Response |
| AR | Master → Slave | Read Address |
| R  | Slave → Master | Read Data & Response |

> Write 시 Data와 Response가 별도 채널인 이유: Slave가 데이터를 실제로 처리해봐야 유효 여부를 알 수 있기 때문  
> Read 시 Data와 Response가 같은 채널(R)인 이유: Slave가 이미 데이터 유효 여부를 알고 있으므로 동시에 내보낼 수 있음

### 핸드셰이크 동작

모든 채널은 **VALID & READY 핸드셰이크** 방식으로 동작합니다.

```
Source  → VALID, INFO
Destination → READY

VALID & READY가 동시에 1인 클럭 엣지 → Handshake 완료
```

- VALID: Source → Destination 방향
- READY: Destination → Source 방향
- Master/Slave 중 누가 Source인지는 채널마다 다름

**방법 1**: Source가 먼저 VALID를 올리고 Destination이 확인 후 READY 응답 (2클럭 소요)  
**방법 2**: Destination이 READY를 미리 올려두면 VALID 확인 즉시 핸드셰이크 가능 (1클럭 절약)

### RESP 인코딩 (2bit)

| 값 | 이름 | 의미 |
|----|------|------|
| 2'b00 | OKAY | 정상 |
| 2'b01 | EXOKAY | Exclusive access 성공 |
| 2'b10 | SLVERR | Slave 에러 |
| 2'b11 | DECERR | Decode 에러 (주소 없음) |

> Response 채널이 B 채널인 이유: ARM이 그냥 그렇게 정한 것. 공식 의미 없음.

---

## 🏗️ 설계 구조

```
Tester (CPU 역할)
    │
    ▼
AXI4-Lite Master  ──── AW / W / B / AR / R ────  AXI4-Lite Slave
                                                        │
                                                   내부 Register
                                                 [0x00][0x04][0x08][0x0C]
```

### 파일 구성

| 파일 | 설명 |
|------|------|
| `axi4_lite_master.sv` | Master FSM (AW / W / B / AR / R 채널) |
| `axi4_lite_slave.sv` | Slave FSM (AW / W / B / AR / R 채널) |
| `axi4_lite_top.sv` | Master + Slave 연결 Top 모듈 |
| `tb_axi4_lite.sv` | Master 단독 테스트벤치 (Slave 동작 task로 구현) |
| `tb_axi4_top.sv` | Top 모듈 테스트벤치 |

---

## ⚙️ Master 설계

Write / Read 트랜잭션 각각 독립적인 FSM으로 구현했습니다.

### Write Transaction FSM

```
AW_IDLE ──(transfer & write)──► AW_VALID ──(AWREADY)──► AW_IDLE
W_IDLE  ──(transfer & write)──► W_VALID  ──(WREADY) ──► W_IDLE
B_IDLE  ──(WVALID)           ──► B_READY  ──(BVALID) ──► B_IDLE
```

### Read Transaction FSM

```
AR_IDLE ──(transfer & !write)──► AR_VALID ──(ARREADY)──► AR_IDLE
R_IDLE  ──(ARVALID)           ──► R_READY  ──(RVALID) ──► R_IDLE
```

**설계 포인트**
- `ready` 신호: `w_ready | r_ready` OR 조합 출력 (write/read 동시 동작 없으므로 충돌 없음)
- `w_ready`: B 채널에서 `B_READY → B_IDLE` 천이 시 1

---

## ⚙️ Slave 설계

### Write Transaction FSM

```
AW_IDLE ──(AWVALID)──► AW_READY  : addr_reg 저장, AWREADY = 1
W_IDLE  ──(WVALID) ──► W_READY   : mem[addr_reg] 에 WDATA 저장, WREADY = 1
B_IDLE  ──(WVALID & WREADY)──► B_VALID : BVALID = 1
B_VALID ──(BVALID & BREADY) ──► B_IDLE
```

### Read Transaction FSM

```
AR_IDLE ──(ARVALID)──► AR_READY  : addr_reg 저장, ARREADY = 1
R_IDLE  ──(ARREADY)──► R_VALID   : RDATA = mem[addr_reg], RVALID = 1
R_VALID ──(RVALID & RREADY)──► R_IDLE
```

**내부 레지스터 맵**

| Offset | 레지스터 |
|--------|---------|
| 0x00 | mem[0] |
| 0x04 | mem[1] |
| 0x08 | mem[2] |
| 0x0C | mem[3] |

---

## ✅ 시뮬레이션 결과

테스트벤치에서 `axi_write` / `axi_read` task를 이용해 4개 레지스터에 Write 후 Read 검증을 수행했습니다.

```
axi_write(0x0000_0000, 0x1111_1111)
axi_write(0x0000_0004, 0x2222_2222)
axi_write(0x0000_0008, 0x3333_3333)
axi_write(0x0000_000C, 0x4444_4444)

axi_read(0x0000_0000) → 0x1111_1111 ✅
axi_read(0x0000_0004) → 0x2222_2222 ✅
axi_read(0x0000_0008) → 0x3333_3333 ✅
axi_read(0x0000_000C) → 0x4444_4444 ✅
```

---

## 🔧 FPGA 동작: FND 카운터

MicroBlaze + AXI 구조를 이용해 버튼 입력 기반 4자리 FND 카운터를 구현했습니다.

**동작 방식**
1. 버튼 1 (run): 카운터 동작 시작
2. 버튼 0 (clear): 카운터 리셋 및 FND 초기화
3. 버튼 2 (stop): 카운터 정지
4. 카운터 값을 자릿수별로 분리 → FND 세그먼트 데이터로 변환 → `fnd_digit` / `fnd_data` 레지스터에 쓰기

**GPIO 레지스터 맵**

| Define | Offset | 역할 |
|--------|--------|------|
| `GPIO_CR` | 0x00 | 방향 설정 (0x00: 입력 모드) |
| `GPIO_IDR` | 0x04 | 버튼 입력 읽기 |
| `GPIO_ODR` | 0x08 | LED 출력 |
| `fnd_digit` | 0x00 | FND 자릿수 선택 |
| `fnd_data`  | 0x04 | FND 세그먼트 데이터 |

---

## 🐛 Trouble Shooting

### FND 출력이 변하지 않고 전부 켜져 있는 문제

**문제**  
`fnd_digit`을 `0x1`, `0x2`, `0x4`, `0x8`로 설정했으나 FND가 전혀 변하지 않고 모두 켜진 채로 유지됨

**원인**  
FND의 digit select는 **Active Low** 방식 → `0`이 켜짐, `1`이 꺼짐  
`decoder_2x4` 모듈 출력 확인 결과, `4'b1110` / `4'b1101` / `4'b1011` / `4'b0111` 형태가 맞음  
즉, `0x1` → `0xe`, `0x2` → `0xd`, `0x4` → `0xb`, `0x8` → `0x7` 로 보내야 함

**해결**  
`fnd_digit` 값을 Active Low 방식에 맞게 수정

```c
// 수정 전 (잘못됨)
*(uint32_t *) fnd_digit = 0x1;

// 수정 후 (올바름)
*(uint32_t *) fnd_digit = 0xe;
```

---

## 💬 느낀 점

- AXI 채널별 핸드셰이크 방향(Source/Destination)을 직접 구현하면서 프로토콜 구조를 확실히 이해하게 됨
- Write와 Read의 Response 채널 구조가 다른 이유를 설계 과정에서 자연스럽게 체득
- Active Low 방식의 하드웨어 특성을 간과한 실수를 통해 RTL-SW 인터페이스 디버깅 능력 향상
