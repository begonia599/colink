<script lang="ts" setup>
import { ref, computed } from 'vue'

interface Node {
  id: string
  name: string
  configured: boolean
  // 配置完成后才有的字段
  server?: string
  port?: number
  key?: string
  crypt?: string
  mode?: string
  localPort?: number
}

const nodes = ref<Node[]>([])
const selectedNodeId = ref<string | null>(null)
const isConnected = ref(false)
const isConnecting = ref(false)

// 弹窗状态
const showAddModal = ref(false)
const showConfigModal = ref(false)
const configNodeId = ref<string | null>(null)

// 新节点名称
const newNodeName = ref('')

// 配置粘贴内容
const configPasteContent = ref('')

const selectedNode = computed(() => {
  return nodes.value.find(n => n.id === selectedNodeId.value)
})

const configNode = computed(() => {
  return nodes.value.find(n => n.id === configNodeId.value)
})

// 生成部署命令
const deployCommand = computed(() => {
  if (!configNode.value) return ''
  // TODO: 后续替换成真实的脚本地址
  return `curl -fsSL https://your-domain.com/deploy.sh | bash -s -- --id=${configNode.value.id}`
})

function selectNode(id: string) {
  const node = nodes.value.find(n => n.id === id)
  if (!isConnected.value && node?.configured) {
    selectedNodeId.value = id
  }
}

function addNode() {
  if (!newNodeName.value.trim()) return
  
  const node: Node = {
    id: Date.now().toString(),
    name: newNodeName.value.trim(),
    configured: false
  }
  nodes.value.push(node)
  showAddModal.value = false
  newNodeName.value = ''
  saveNodes()
}

function openConfigModal(id: string) {
  configNodeId.value = id
  configPasteContent.value = ''
  showConfigModal.value = true
}

function copyCommand() {
  navigator.clipboard.writeText(deployCommand.value)
}

function applyConfig() {
  if (!configNodeId.value || !configPasteContent.value.trim()) return
  
  try {
    // 解析粘贴的配置（预期是 JSON 格式）
    const config = JSON.parse(configPasteContent.value.trim())
    const node = nodes.value.find(n => n.id === configNodeId.value)
    if (node) {
      node.server = config.server
      node.port = config.port
      node.key = config.key
      node.crypt = config.crypt || 'aes'
      node.mode = config.mode || 'fast2'
      node.localPort = config.localPort || 25565
      node.configured = true
      saveNodes()
    }
    showConfigModal.value = false
    configPasteContent.value = ''
  } catch (e) {
    alert('配置格式错误，请检查粘贴的内容')
  }
}

function deleteNode(id: string) {
  nodes.value = nodes.value.filter(n => n.id !== id)
  if (selectedNodeId.value === id) {
    selectedNodeId.value = null
  }
  saveNodes()
}

async function toggleConnection() {
  if (isConnected.value) {
    isConnected.value = false
  } else if (selectedNode.value) {
    isConnecting.value = true
    // TODO: 调用后端连接方法
    setTimeout(() => {
      isConnected.value = true
      isConnecting.value = false
    }, 1000)
  }
}

function saveNodes() {
  localStorage.setItem('colink_nodes', JSON.stringify(nodes.value))
}

function loadNodes() {
  const saved = localStorage.getItem('colink_nodes')
  if (saved) {
    nodes.value = JSON.parse(saved)
  }
}

loadNodes()
</script>

<template>
  <div class="titlebar">
    <span class="titlebar-title">CoLink</span>
  </div>

  <div class="main-container">
    <!-- 连接状态卡片 -->
    <div class="status-card">
      <div class="status-info">
        <div class="status-dot" :class="{ connected: isConnected }"></div>
        <div class="status-text">
          <span class="label">状态:</span>
          <span v-if="isConnecting">连接中...</span>
          <span v-else-if="isConnected">已连接 - {{ selectedNode?.name }}</span>
          <span v-else>未连接</span>
        </div>
      </div>
      <button 
        class="btn" 
        :class="isConnected ? 'btn-danger' : 'btn-primary'"
        :disabled="!selectedNode && !isConnected || isConnecting"
        @click="toggleConnection"
      >
        {{ isConnected ? '断开' : '连接' }}
      </button>
    </div>

    <!-- 节点列表 -->
    <div class="nodes-section">
      <div class="section-header">
        <h3 class="section-title">节点列表</h3>
        <button class="btn btn-add" @click="showAddModal = true">+ 添加节点</button>
      </div>

      <div class="nodes-list" v-if="nodes.length > 0">
        <div 
          v-for="node in nodes" 
          :key="node.id"
          class="node-item"
          :class="{ 
            active: node.id === selectedNodeId,
            unconfigured: !node.configured 
          }"
          @click="selectNode(node.id)"
        >
          <div class="node-info">
            <div class="node-icon" :class="{ unconfigured: !node.configured }">
              {{ node.configured ? '🖥️' : '⚙️' }}
            </div>
            <div class="node-details">
              <h4>{{ node.name }}</h4>
              <p v-if="node.configured">{{ node.server }}:{{ node.port }}</p>
              <p v-else class="unconfigured-text">未配置 - 点击右侧按钮配置</p>
            </div>
          </div>
          <div class="node-actions" @click.stop>
            <button 
              v-if="!node.configured" 
              class="btn-icon config" 
              @click="openConfigModal(node.id)"
              title="配置节点"
            >
              ⬇️
            </button>
            <button 
              class="btn-icon delete" 
              @click="deleteNode(node.id)" 
              :disabled="isConnected && node.id === selectedNodeId"
              title="删除节点"
            >
              🗑️
            </button>
          </div>
        </div>
      </div>

      <div class="empty-state" v-else>
        <div class="empty-state-icon">📡</div>
        <p>暂无节点，点击上方添加</p>
      </div>
    </div>
  </div>

  <!-- 添加节点模态框 -->
  <div class="modal-overlay" v-if="showAddModal" @click.self="showAddModal = false">
    <div class="modal modal-small">
      <h3>添加节点</h3>
      <div class="form-group">
        <label>节点名称</label>
        <input 
          v-model="newNodeName" 
          placeholder="例如: 我的台湾节点"
          @keyup.enter="addNode"
        />
      </div>
      <div class="modal-actions">
        <button class="btn btn-secondary" @click="showAddModal = false">取消</button>
        <button class="btn btn-primary" @click="addNode" :disabled="!newNodeName.trim()">
          添加
        </button>
      </div>
    </div>
  </div>

  <!-- 配置节点模态框 -->
  <div class="modal-overlay" v-if="showConfigModal" @click.self="showConfigModal = false">
    <div class="modal">
      <h3>配置节点: {{ configNode?.name }}</h3>
      
      <div class="config-step">
        <div class="step-number">1</div>
        <div class="step-content">
          <p class="step-title">复制以下命令到你的节点服务器执行</p>
          <div class="command-box">
            <code>{{ deployCommand }}</code>
            <button class="btn-copy" @click="copyCommand" title="复制">📋</button>
          </div>
        </div>
      </div>

      <div class="config-step">
        <div class="step-number">2</div>
        <div class="step-content">
          <p class="step-title">将服务器输出的配置信息粘贴到下方</p>
          <textarea 
            v-model="configPasteContent" 
            placeholder='粘贴服务器输出的配置信息...'
            rows="5"
          ></textarea>
        </div>
      </div>

      <div class="modal-actions">
        <button class="btn btn-secondary" @click="showConfigModal = false">取消</button>
        <button class="btn btn-primary" @click="applyConfig" :disabled="!configPasteContent.trim()">
          完成配置
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.node-item.unconfigured {
  border-style: dashed;
  opacity: 0.8;
}

.node-icon.unconfigured {
  background: rgba(251, 191, 36, 0.2);
}

.unconfigured-text {
  color: #fbbf24;
  font-style: italic;
}

.btn-icon.config {
  background: rgba(59, 130, 246, 0.2);
  color: #3b82f6;
}

.btn-icon.config:hover {
  background: rgba(59, 130, 246, 0.3);
}

.modal-small {
  max-width: 340px;
}

.config-step {
  display: flex;
  gap: 14px;
  margin-bottom: 20px;
}

.step-number {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 600;
  flex-shrink: 0;
}

.step-content {
  flex: 1;
}

.step-title {
  font-size: 14px;
  color: #a1a1aa;
  margin-bottom: 10px;
}

.command-box {
  background: rgba(0, 0, 0, 0.3);
  border-radius: 8px;
  padding: 12px;
  display: flex;
  align-items: center;
  gap: 10px;
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.command-box code {
  flex: 1;
  font-family: 'Consolas', 'Monaco', monospace;
  font-size: 12px;
  color: #22c55e;
  word-break: break-all;
}

.btn-copy {
  background: rgba(255, 255, 255, 0.1);
  border: none;
  border-radius: 6px;
  padding: 6px 10px;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-copy:hover {
  background: rgba(255, 255, 255, 0.2);
}

.step-content textarea {
  width: 100%;
  padding: 12px;
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.15);
  background: rgba(0, 0, 0, 0.3);
  color: #22c55e;
  font-size: 13px;
  font-family: 'Consolas', 'Monaco', monospace;
  resize: vertical;
  min-height: 100px;
}

.step-content textarea::placeholder {
  color: #52525b;
}

.step-content textarea:focus {
  outline: none;
  border-color: #3b82f6;
  background: rgba(0, 0, 0, 0.4);
}
</style>
