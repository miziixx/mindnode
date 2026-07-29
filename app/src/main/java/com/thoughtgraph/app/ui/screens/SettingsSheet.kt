package com.thoughtgraph.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.thoughtgraph.app.settings.SecureCredentialStore
import com.thoughtgraph.app.settings.SettingsStore
import com.thoughtgraph.app.ui.theme.Accent
import com.thoughtgraph.app.ui.theme.Danger
import com.thoughtgraph.app.ui.theme.DangerSoft
import com.thoughtgraph.app.ui.theme.Line
import com.thoughtgraph.app.ui.theme.Muted
import com.thoughtgraph.app.ui.theme.Panel
import com.thoughtgraph.app.ui.theme.YellowSoft

private val providers = listOf(
    "anthropic" to "Anthropic",
    "openai" to "OpenAI",
    "gemini" to "Google Gemini",
    "custom" to "사용자 지정"
)

@Composable
fun SettingsSheet(
    settings: SettingsStore,
    credentials: SecureCredentialStore,
    onClose: () -> Unit,
    onToast: (String) -> Unit
) {
    var aiEnabled by remember { mutableStateOf(settings.aiEnabled) }
    var selectedOnly by remember { mutableStateOf(settings.selectedOnly) }
    var provider by remember { mutableStateOf(settings.provider) }
    var apiKey by remember { mutableStateOf(credentials.getApiKey()) }
    var model by remember { mutableStateOf(settings.model) }
    var endpoint by remember { mutableStateOf(settings.customEndpoint) }
    var autoSave by remember { mutableStateOf(settings.autoSave) }
    var noHistory by remember { mutableStateOf(settings.noHistory) }
    var miniMap by remember { mutableStateOf(settings.showMiniMap) }
    var contrast by remember { mutableStateOf(settings.highContrast) }
    var keyVisible by remember { mutableStateOf(false) }
    var providerMenu by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Panel)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onClose) {
                Icon(Icons.Filled.ArrowBack, contentDescription = "설정 닫기")
            }
            Column(modifier = Modifier.padding(start = 6.dp)) {
                Text("설정", fontSize = 18.sp, fontWeight = FontWeight.Black)
                Text("AI는 선택 기능이며 기본값은 사용 안 함입니다.", color = Muted, fontSize = 10.sp)
            }
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            Section("AI 사용 방식", "핵심 기능은 AI 없이 작동합니다. 아래를 켠 경우에만 API를 사용합니다.") {
                SettingLine("AI 보조 사용", "빈틈 찾기·반대 관점·문장 구체화", aiEnabled) { aiEnabled = it }
                SettingLine("수동 호출만 허용", "자동 분석 및 백그라운드 호출 금지 (고정)", true, enabled = false) {}
                SettingLine("선택한 노드만 전송", "그래프 전체를 자동 전송하지 않음", selectedOnly) { selectedOnly = it }
            }

            Section("API 연결", "키를 입력해도 AI 사용을 켜지 않으면 호출되지 않습니다.") {
                FieldLabel("제공자")
                Box {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .border(1.dp, Line, RoundedCornerShape(12.dp))
                            .clickable { providerMenu = true }
                            .padding(14.dp)
                    ) {
                        Text(providers.firstOrNull { it.first == provider }?.second ?: "Anthropic", fontSize = 12.sp)
                    }
                    DropdownMenu(expanded = providerMenu, onDismissRequest = { providerMenu = false }) {
                        providers.forEach { (value, label) ->
                            DropdownMenuItem(text = { Text(label) }, onClick = {
                                provider = value; providerMenu = false
                            })
                        }
                    }
                }

                FieldLabel("API 키")
                OutlinedTextField(
                    value = apiKey,
                    onValueChange = { apiKey = it },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    placeholder = { Text("sk- 또는 API 키 입력") },
                    visualTransformation = if (keyVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = {
                        IconButton(onClick = { keyVisible = !keyVisible }) {
                            Icon(
                                if (keyVisible) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                                contentDescription = if (keyVisible) "키 숨기기" else "키 표시"
                            )
                        }
                    }
                )

                FieldLabel("모델")
                OutlinedTextField(
                    value = model,
                    onValueChange = { model = it },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    placeholder = { Text("사용할 모델 ID 직접 입력") }
                )

                if (provider == "custom") {
                    FieldLabel("사용자 지정 엔드포인트")
                    OutlinedTextField(
                        value = endpoint,
                        onValueChange = { endpoint = it },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        placeholder = { Text("https://example.com/v1/chat/completions") }
                    )
                }

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp)
                        .clip(RoundedCornerShape(13.dp))
                        .background(YellowSoft)
                        .padding(11.dp)
                ) {
                    Text(
                        "API 키는 Android Keystore 기반 보안 저장소에만 저장되며, 일반 DB·로그·백업에는 저장되지 않습니다.",
                        color = Color2(0xFF796635), fontSize = 9.sp
                    )
                }

                GhostButton("연결 설정 확인") {
                    when {
                        !aiEnabled -> onToast("AI 보조를 먼저 켜세요.")
                        apiKey.isBlank() -> onToast("API 키를 입력하세요.")
                        model.isBlank() -> onToast("모델 ID를 입력하세요.")
                        else -> onToast("설정이 유효합니다. 저장 후 노드에서 직접 호출하세요.")
                    }
                }
            }

            Section("로컬 저장", "로그인 없이 기기에서 먼저 작동하는 구조입니다.") {
                SettingLine("자동 저장", "노드 변경 즉시 기기에 저장", autoSave) { autoSave = it }
                SettingLine("사용 기록 저장 안 함", "API 요청·응답 원문을 남기지 않음", noHistory) { noHistory = it }
            }

            Section("화면", "모바일에서 캔버스를 최대한 넓게 사용합니다.") {
                SettingLine("미니맵 표시", "작은 화면에서는 자동 숨김", miniMap) { miniMap = it }
                SettingLine("고대비 모드", "텍스트와 테두리 대비 강화", contrast) { contrast = it }
            }
        }

        // Actions
        Row(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Button(
                onClick = {
                    apiKey = ""; endpoint = ""; aiEnabled = false
                    credentials.clear()
                    onToast("API 정보를 지웠습니다.")
                },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = DangerSoft, contentColor = Danger)
            ) { Text("API 정보 지우기", fontSize = 11.sp, fontWeight = FontWeight.Black) }

            Button(
                onClick = {
                    settings.aiEnabled = aiEnabled
                    settings.selectedOnly = selectedOnly
                    settings.provider = provider
                    settings.model = model.trim()
                    settings.customEndpoint = endpoint.trim()
                    settings.autoSave = autoSave
                    settings.noHistory = noHistory
                    settings.showMiniMap = miniMap
                    settings.highContrast = contrast
                    // Secure store, kept separate from all other prefs.
                    credentials.setApiKey(apiKey)
                    onToast("설정을 기기에 저장했습니다.")
                    onClose()
                },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = Accent, contentColor = androidx.compose.ui.graphics.Color.White)
            ) { Text("설정 저장", fontSize = 11.sp, fontWeight = FontWeight.Black) }
        }
    }
}

@Composable
private fun Section(title: String, sub: String, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp)
            .clip(RoundedCornerShape(17.dp))
            .background(Panel)
            .border(1.dp, Line, RoundedCornerShape(17.dp))
            .padding(15.dp)
    ) {
        Text(title, fontSize = 13.sp, fontWeight = FontWeight.Black)
        Text(sub, color = Muted, fontSize = 9.sp, modifier = Modifier.padding(top = 4.dp, bottom = 4.dp))
        content()
    }
}

@Composable
private fun SettingLine(
    name: String,
    desc: String,
    checked: Boolean,
    enabled: Boolean = true,
    onChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(name, fontSize = 11.sp, fontWeight = FontWeight.Black)
            Text(desc, color = Muted, fontSize = 9.sp)
        }
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            enabled = enabled,
            colors = SwitchDefaults.colors(checkedTrackColor = Accent)
        )
    }
}

@Composable
private fun FieldLabel(text: String) {
    Text(text, fontSize = 9.sp, fontWeight = FontWeight.Black, color = Muted,
        modifier = Modifier.padding(top = 12.dp, bottom = 6.dp))
}

@Composable
private fun GhostButton(text: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp)
            .clip(RoundedCornerShape(10.dp))
            .border(1.dp, Line, RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text, fontSize = 10.sp, fontWeight = FontWeight.Black, color = Muted)
    }
}

private fun Color2(v: Long) = androidx.compose.ui.graphics.Color(v)
