// EnhanceSwarm Web UI JavaScript

// Global state
window.EnhanceSwarm = {
  status: {},
  tasks: {},
  agents: [],
  config: {},
  refreshInterval: null
};

// API helper functions
async function apiRequest(endpoint, options = {}) {
  try {
    const response = await fetch(endpoint, {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('API request failed:', error);
    showNotification('API request failed: ' + error.message, 'error');
    throw error;
  }
}

// Dashboard functions
async function initializeDashboard() {
  try {
    await Promise.all([
      loadStatus(),
      loadConfig(),
      loadProjectInfo()
    ]);
    
    updateDashboard();
  } catch (error) {
    console.error('Failed to initialize dashboard:', error);
    showNotification('Failed to load dashboard data', 'error');
  }
}

async function loadStatus() {
  try {
    const status = await apiRequest('/api/status');
    window.EnhanceSwarm.status = status;
    return status;
  } catch (error) {
    console.error('Failed to load status:', error);
    return {};
  }
}

async function loadTasks() {
  try {
    const tasks = await apiRequest('/api/tasks');
    window.EnhanceSwarm.tasks = tasks;
    return tasks;
  } catch (error) {
    console.error('Failed to load tasks:', error);
    return { tasks: [], folders: [] };
  }
}

async function loadConfig() {
  try {
    const config = await apiRequest('/api/config');
    window.EnhanceSwarm.config = config;
    return config;
  } catch (error) {
    console.error('Failed to load config:', error);
    return {};
  }
}

async function loadProjectInfo() {
  try {
    const projectInfo = await apiRequest('/api/project/analyze');
    window.EnhanceSwarm.projectInfo = projectInfo;
    return projectInfo;
  } catch (error) {
    console.error('Failed to load project info:', error);
    return {};
  }
}

function updateDashboard() {
  updateStatusOverview();
  updateActiveAgents();
  updateRecentTasks();
  updateSystemHealth();
  updateProjectInfo();
}

function updateStatusOverview() {
  const status = window.EnhanceSwarm.status;
  
  // Session status
  const sessionStatus = document.getElementById('session-status');
  if (sessionStatus) {
    const icon = sessionStatus.querySelector('i');
    const value = sessionStatus.querySelector('.status-value');
    
    if (status.session_exists) {
      icon.className = 'fas fa-circle';
      icon.style.color = '#27ae60';
      value.textContent = 'Active';
    } else {
      icon.className = 'fas fa-circle';
      icon.style.color = '#7f8c8d';
      value.textContent = 'Inactive';
    }
  }
  
  // Agents status
  const agentsStatus = document.getElementById('agents-status');
  if (agentsStatus) {
    const value = agentsStatus.querySelector('.status-value');
    value.textContent = status.active_agents || 0;
  }
  
  // Tasks status
  const tasksStatus = document.getElementById('tasks-status');
  if (tasksStatus) {
    const value = tasksStatus.querySelector('.status-value');
    const tasks = window.EnhanceSwarm.tasks;
    value.textContent = tasks.tasks ? tasks.tasks.length : 0;
  }
}

function updateActiveAgents() {
  const container = document.getElementById('active-agents-list');
  if (!container) return;
  
  const status = window.EnhanceSwarm.status;
  
  if (!status.agents || status.agents.length === 0) {
    container.innerHTML = '<div class="text-center text-secondary">No active agents</div>';
    return;
  }
  
  const activeAgents = status.agents.filter(agent => agent.status === 'running');
  
  if (activeAgents.length === 0) {
    container.innerHTML = '<div class="text-center text-secondary">No active agents</div>';
    return;
  }
  
  container.innerHTML = activeAgents.map(agent => `
    <div class="agent-item">
      <div class="agent-icon">
        <i class="fas fa-robot" style="color: #27ae60;"></i>
      </div>
      <div class="agent-info">
        <div class="agent-role">${agent.role.toUpperCase()}</div>
        <div class="agent-details">PID: ${agent.pid} | Runtime: ${calculateRuntime(agent.start_time)}</div>
      </div>
    </div>
  `).join('');
}

function updateRecentTasks() {
  const container = document.getElementById('recent-tasks-list');
  if (!container) return;
  
  const tasks = window.EnhanceSwarm.tasks;
  
  if (!tasks.tasks || tasks.tasks.length === 0) {
    container.innerHTML = '<div class="text-center text-secondary">No tasks found</div>';
    return;
  }
  
  const recentTasks = tasks.tasks.slice(0, 5);
  
  container.innerHTML = recentTasks.map(task => `
    <div class="task-item">
      <div class="task-title">${task.title || 'Untitled Task'}</div>
      <div class="task-status">${task.status || 'unknown'}</div>
    </div>
  `).join('');
}

function updateSystemHealth() {
  const container = document.getElementById('system-health');
  if (!container) return;
  
  const config = window.EnhanceSwarm.config;
  const status = window.EnhanceSwarm.status;
  
  const healthItems = [
    {
      name: 'Configuration',
      status: Object.keys(config).length > 0 ? 'healthy' : 'warning',
      message: Object.keys(config).length > 0 ? 'Loaded' : 'No config found'
    },
    {
      name: 'Task Management',
      status: window.EnhanceSwarm.tasks.swarm_tasks_available ? 'healthy' : 'warning',
      message: window.EnhanceSwarm.tasks.swarm_tasks_available ? 'Available' : 'Limited functionality'
    },
    {
      name: 'Agent System',
      status: status.session_exists ? 'healthy' : 'inactive',
      message: status.session_exists ? 'Session active' : 'No active session'
    }
  ];
  
  container.innerHTML = healthItems.map(item => `
    <div class="health-item">
      <div class="health-icon">
        <i class="fas fa-${item.status === 'healthy' ? 'check-circle' : item.status === 'warning' ? 'exclamation-triangle' : 'times-circle'}" 
           style="color: ${item.status === 'healthy' ? '#27ae60' : item.status === 'warning' ? '#f39c12' : '#e74c3c'};"></i>
      </div>
      <div class="health-info">
        <div class="health-name">${item.name}</div>
        <div class="health-message">${item.message}</div>
      </div>
    </div>
  `).join('');
}

function updateProjectInfo() {
  const container = document.getElementById('project-info');
  if (!container) return;
  
  const projectInfo = window.EnhanceSwarm.projectInfo;
  
  if (!projectInfo || !projectInfo.analysis) {
    container.innerHTML = '<div class="text-center text-secondary">No project analysis available</div>';
    return;
  }
  
  const analysis = projectInfo.analysis;
  
  container.innerHTML = `
    <div class="project-detail">
      <strong>Type:</strong> ${analysis.project_type || 'Unknown'}
    </div>
    <div class="project-detail">
      <strong>Stack:</strong> ${analysis.technology_stack ? analysis.technology_stack.join(', ') : 'Not detected'}
    </div>
    <div class="project-detail">
      <strong>Testing:</strong> ${analysis.testing_framework ? analysis.testing_framework.join(', ') : 'None detected'}
    </div>
    <div class="project-detail">
      <strong>Documentation:</strong> ${analysis.documentation && analysis.documentation.has_docs ? 'Available' : 'None found'}
    </div>
  `;
}

// Agent management
async function spawnAgent() {
  openModal('spawn-agent-modal');
}

async function submitSpawnAgent(formData) {
  try {
    const result = await apiRequest('/api/agents/spawn', {
      method: 'POST',
      body: JSON.stringify(formData)
    });
    
    if (result.success) {
      showNotification(`${formData.role.charAt(0).toUpperCase() + formData.role.slice(1)} agent spawned successfully (PID: ${result.pid})`, 'success');
      closeModal('spawn-agent-modal');
      await refreshData();
    } else {
      throw new Error(result.message);
    }
  } catch (error) {
    showNotification('Failed to spawn agent: ' + error.message, 'error');
  }
}

// Quick actions
async function enhanceProject() {
  showNotification('Starting project enhancement...', 'info');
  // This would trigger the enhance protocol
  // For now, just show a message
  setTimeout(() => {
    showNotification('Enhancement protocol would be triggered here', 'info');
  }, 1000);
}

async function analyzeProject() {
  showNotification('Analyzing project...', 'info');
  try {
    await loadProjectInfo();
    updateProjectInfo();
    showNotification('Project analysis completed', 'success');
  } catch (error) {
    showNotification('Project analysis failed: ' + error.message, 'error');
  }
}

function viewMonitoring() {
  window.location.href = '/agents';
}

function setupTasks() {
  window.location.href = '/kanban';
}

// Utility functions
function calculateRuntime(startTime) {
  if (!startTime) return 'Unknown';
  
  try {
    const start = new Date(startTime);
    const now = new Date();
    const diff = Math.floor((now - start) / 1000);
    
    if (diff < 60) return `${diff}s`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m`;
    return `${Math.floor(diff / 3600)}h`;
  } catch (error) {
    return 'Unknown';
  }
}

function formatDate(dateString) {
  if (!dateString) return 'Unknown';
  
  try {
    const date = new Date(dateString);
    return date.toLocaleString();
  } catch (error) {
    return 'Unknown';
  }
}

// Modal management
function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.add('show');
    document.body.style.overflow = 'hidden';
  }
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.remove('show');
    document.body.style.overflow = '';
  }
}

// Click outside modal to close
document.addEventListener('click', function(event) {
  if (event.target.classList.contains('modal')) {
    closeModal(event.target.id);
  }
});

// Escape key to close modal
document.addEventListener('keydown', function(event) {
  if (event.key === 'Escape') {
    const openModal = document.querySelector('.modal.show');
    if (openModal) {
      closeModal(openModal.id);
    }
  }
});

// Form handling
document.addEventListener('submit', function(event) {
  if (event.target.id === 'spawn-agent-form') {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const data = {
      role: formData.get('role'),
      task: formData.get('task'),
      worktree: formData.get('worktree') === 'on'
    };
    
    submitSpawnAgent(data);
  }
});

// Notifications
function showNotification(message, type = 'info') {
  // Create notification element
  const notification = document.createElement('div');
  notification.className = `notification notification-${type}`;
  notification.innerHTML = `
    <div class="notification-content">
      <i class="fas fa-${type === 'success' ? 'check-circle' : type === 'error' ? 'exclamation-circle' : 'info-circle'}"></i>
      <span>${message}</span>
    </div>
    <button class="notification-close" onclick="this.parentElement.remove()">
      <i class="fas fa-times"></i>
    </button>
  `;
  
  // Add to page
  let container = document.getElementById('notification-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'notification-container';
    container.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 10000;
      max-width: 400px;
    `;
    document.body.appendChild(container);
  }
  
  container.appendChild(notification);
  
  // Auto remove after 5 seconds
  setTimeout(() => {
    if (notification.parentElement) {
      notification.remove();
    }
  }, 5000);
}

// Auto refresh
function startAutoRefresh() {
  // Refresh every 30 seconds
  window.EnhanceSwarm.refreshInterval = setInterval(async () => {
    try {
      await Promise.all([
        loadStatus(),
        loadTasks()
      ]);
      updateDashboard();
    } catch (error) {
      console.error('Auto refresh failed:', error);
    }
  }, 30000);
}

function stopAutoRefresh() {
  if (window.EnhanceSwarm.refreshInterval) {
    clearInterval(window.EnhanceSwarm.refreshInterval);
    window.EnhanceSwarm.refreshInterval = null;
  }
}

async function refreshData() {
  try {
    await Promise.all([
      loadStatus(),
      loadTasks(),
      loadConfig()
    ]);
    updateDashboard();
    showNotification('Data refreshed', 'success');
  } catch (error) {
    showNotification('Failed to refresh data', 'error');
  }
}

// Add notification styles to head
const notificationStyles = `
  .notification {
    background: white;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    margin-bottom: 10px;
    padding: 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    animation: slideInRight 0.3s ease;
  }
  
  .notification-success { border-left: 4px solid #27ae60; }
  .notification-error { border-left: 4px solid #e74c3c; }
  .notification-info { border-left: 4px solid #3498db; }
  
  .notification-content {
    display: flex;
    align-items: center;
  }
  
  .notification-content i {
    margin-right: 8px;
    font-size: 18px;
  }
  
  .notification-success .notification-content i { color: #27ae60; }
  .notification-error .notification-content i { color: #e74c3c; }
  .notification-info .notification-content i { color: #3498db; }
  
  .notification-close {
    background: none;
    border: none;
    cursor: pointer;
    color: #7f8c8d;
    padding: 4px;
  }
  
  .notification-close:hover {
    color: #2c3e50;
  }
  
  @keyframes slideInRight {
    from {
      transform: translateX(100%);
      opacity: 0;
    }
    to {
      transform: translateX(0);
      opacity: 1;
    }
  }
`;

const styleSheet = document.createElement('style');
styleSheet.textContent = notificationStyles;
document.head.appendChild(styleSheet);