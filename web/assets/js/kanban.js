// Kanban Board JavaScript for EnhanceSwarm

// Kanban state
window.KanbanBoard = {
  columns: [
    { id: 'todo', title: 'To Do', tasks: [] },
    { id: 'in_progress', title: 'In Progress', tasks: [] },
    { id: 'review', title: 'Review', tasks: [] },
    { id: 'done', title: 'Done', tasks: [] }
  ],
  sortables: {}
};

// Initialize kanban board
function initializeKanban() {
  console.log('Initializing Kanban board...');
}

// Load kanban data
async function loadKanbanData() {
  try {
    const taskData = await apiRequest('/api/tasks');
    
    // Process task data
    processTaskData(taskData);
    
    // Render kanban board
    renderKanbanBoard();
    
    // Update stats
    updateKanbanStats();
    
  } catch (error) {
    console.error('Failed to load kanban data:', error);
    showKanbanError('Failed to load task data');
  }
}

function processTaskData(taskData) {
  // Reset columns
  window.KanbanBoard.columns.forEach(column => {
    column.tasks = [];
  });
  
  // Process swarm-tasks data
  if (taskData.tasks && Array.isArray(taskData.tasks)) {
    taskData.tasks.forEach(task => {
      const column = findColumnByTaskStatus(task.status);
      if (column) {
        column.tasks.push(formatTask(task));
      }
    });
  }
  
  // Process folder-based tasks
  if (taskData.folders && Array.isArray(taskData.folders)) {
    taskData.folders.forEach(folder => {
      const column = window.KanbanBoard.columns.find(col => col.id === folder.name);
      if (column && folder.task_count > 0) {
        // Add placeholder tasks for folder-based tasks
        for (let i = 0; i < folder.task_count; i++) {
          column.tasks.push({
            id: `${folder.name}_${i}`,
            title: `Task from ${folder.name}`,
            description: `File-based task in ${folder.path}`,
            priority: 'medium',
            category: 'file-based',
            agents: [],
            created_at: new Date().toISOString()
          });
        }
      }
    });
  }
}

function findColumnByTaskStatus(status) {
  const statusMap = {
    'todo': 'todo',
    'pending': 'todo',
    'active': 'in_progress',
    'in_progress': 'in_progress',
    'working': 'in_progress',
    'review': 'review',
    'testing': 'review',
    'done': 'done',
    'completed': 'done',
    'finished': 'done'
  };
  
  const mappedStatus = statusMap[status] || 'todo';
  return window.KanbanBoard.columns.find(col => col.id === mappedStatus);
}

function formatTask(task) {
  return {
    id: task.id || generateTaskId(),
    title: task.title || task.name || 'Untitled Task',
    description: task.description || task.content || '',
    priority: task.priority || 'medium',
    category: task.category || task.type || 'general',
    agents: task.agents || task.recommended_agents || [],
    created_at: task.created_at || task.start_time || new Date().toISOString(),
    updated_at: task.updated_at || task.end_time,
    status: task.status || 'todo'
  };
}

function generateTaskId() {
  return 'task_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

function renderKanbanBoard() {
  const board = document.getElementById('kanban-board');
  if (!board) return;
  
  board.innerHTML = window.KanbanBoard.columns.map(column => 
    renderKanbanColumn(column)
  ).join('');
  
  // Initialize drag and drop
  initializeDragAndDrop();
}

function renderKanbanColumn(column) {
  return `
    <div class="kanban-column" data-column-id="${column.id}">
      <div class="kanban-column-header">
        <span class="kanban-column-title">${column.title}</span>
        <span class="kanban-column-count">${column.tasks.length}</span>
      </div>
      <div class="kanban-column-body" id="column-${column.id}">
        ${column.tasks.map(task => renderTaskCard(task)).join('')}
      </div>
    </div>
  `;
}

function renderTaskCard(task) {
  return `
    <div class="task-card" data-task-id="${task.id}" onclick="openTaskDetails('${task.id}')">
      <div class="task-title">${escapeHtml(task.title)}</div>
      ${task.description ? `<div class="task-description">${escapeHtml(task.description.substring(0, 100))}${task.description.length > 100 ? '...' : ''}</div>` : ''}
      <div class="task-meta">
        <span class="task-priority ${task.priority}">${task.priority.toUpperCase()}</span>
        <span class="task-date">${formatTaskDate(task.created_at)}</span>
      </div>
      ${task.agents && task.agents.length > 0 ? `
        <div class="task-agents">
          ${task.agents.slice(0, 3).map(agent => `<span class="task-agent">${agent}</span>`).join('')}
          ${task.agents.length > 3 ? `<span class="task-agent-more">+${task.agents.length - 3}</span>` : ''}
        </div>
      ` : ''}
    </div>
  `;
}

function initializeDragAndDrop() {
  // Destroy existing sortables
  Object.values(window.KanbanBoard.sortables).forEach(sortable => {
    if (sortable && typeof sortable.destroy === 'function') {
      sortable.destroy();
    }
  });
  window.KanbanBoard.sortables = {};
  
  // Check if Sortable is available
  if (typeof Sortable === 'undefined') {
    console.warn('Sortable.js not loaded, drag and drop disabled');
    return;
  }
  
  // Initialize sortable for each column
  window.KanbanBoard.columns.forEach(column => {
    const columnElement = document.getElementById(`column-${column.id}`);
    if (columnElement) {
      window.KanbanBoard.sortables[column.id] = Sortable.create(columnElement, {
        group: 'kanban',
        animation: 150,
        ghostClass: 'task-card-ghost',
        dragClass: 'task-card-drag',
        onEnd: function(evt) {
          handleTaskMove(evt);
        }
      });
    }
  });
}

function handleTaskMove(evt) {
  const taskId = evt.item.dataset.taskId;
  const newColumnId = evt.to.closest('.kanban-column').dataset.columnId;
  const oldColumnId = evt.from.closest('.kanban-column').dataset.columnId;
  
  if (newColumnId === oldColumnId) return;
  
  console.log(`Moving task ${taskId} from ${oldColumnId} to ${newColumnId}`);
  
  // Update local state
  moveTaskBetweenColumns(taskId, oldColumnId, newColumnId);
  
  // Update column counts
  updateColumnCounts();
  
  // Show success message
  showNotification(`Task moved to ${getColumnTitle(newColumnId)}`, 'success');
  
  // TODO: Send API request to update task status
  // updateTaskStatus(taskId, newColumnId);
}

function moveTaskBetweenColumns(taskId, fromColumnId, toColumnId) {
  const fromColumn = window.KanbanBoard.columns.find(col => col.id === fromColumnId);
  const toColumn = window.KanbanBoard.columns.find(col => col.id === toColumnId);
  
  if (!fromColumn || !toColumn) return;
  
  const taskIndex = fromColumn.tasks.findIndex(task => task.id === taskId);
  if (taskIndex === -1) return;
  
  const task = fromColumn.tasks.splice(taskIndex, 1)[0];
  task.status = toColumnId;
  task.updated_at = new Date().toISOString();
  
  toColumn.tasks.push(task);
}

function getColumnTitle(columnId) {
  const column = window.KanbanBoard.columns.find(col => col.id === columnId);
  return column ? column.title : columnId;
}

function updateColumnCounts() {
  window.KanbanBoard.columns.forEach(column => {
    const countElement = document.querySelector(`[data-column-id="${column.id}"] .kanban-column-count`);
    if (countElement) {
      countElement.textContent = column.tasks.length;
    }
  });
}

function updateKanbanStats() {
  const totalTasks = window.KanbanBoard.columns.reduce((sum, col) => sum + col.tasks.length, 0);
  const activeTasks = window.KanbanBoard.columns.find(col => col.id === 'in_progress')?.tasks.length || 0;
  const completedTasks = window.KanbanBoard.columns.find(col => col.id === 'done')?.tasks.length || 0;
  
  document.getElementById('total-tasks').textContent = totalTasks;
  document.getElementById('active-tasks').textContent = activeTasks;
  document.getElementById('completed-tasks').textContent = completedTasks;
}

// Task management functions
function createTask() {
  openModal('create-task-modal');
}

function openTaskDetails(taskId) {
  const task = findTaskById(taskId);
  if (!task) return;
  
  const modal = document.getElementById('task-details-modal');
  const title = document.getElementById('task-details-title');
  const body = document.getElementById('task-details-body');
  
  title.textContent = task.title;
  body.innerHTML = `
    <div class="task-details">
      <div class="detail-row">
        <strong>Description:</strong>
        <p>${escapeHtml(task.description) || 'No description provided'}</p>
      </div>
      <div class="detail-row">
        <strong>Priority:</strong>
        <span class="task-priority ${task.priority}">${task.priority.toUpperCase()}</span>
      </div>
      <div class="detail-row">
        <strong>Category:</strong>
        <span>${task.category}</span>
      </div>
      <div class="detail-row">
        <strong>Status:</strong>
        <span>${task.status}</span>
      </div>
      <div class="detail-row">
        <strong>Created:</strong>
        <span>${formatTaskDate(task.created_at)}</span>
      </div>
      ${task.updated_at ? `
        <div class="detail-row">
          <strong>Updated:</strong>
          <span>${formatTaskDate(task.updated_at)}</span>
        </div>
      ` : ''}
      ${task.agents && task.agents.length > 0 ? `
        <div class="detail-row">
          <strong>Recommended Agents:</strong>
          <div class="agent-tags">
            ${task.agents.map(agent => `<span class="agent-tag">${agent}</span>`).join('')}
          </div>
        </div>
      ` : ''}
    </div>
  `;
  
  openModal('task-details-modal');
}

function findTaskById(taskId) {
  for (const column of window.KanbanBoard.columns) {
    const task = column.tasks.find(t => t.id === taskId);
    if (task) return task;
  }
  return null;
}

// Form handling for task creation
document.addEventListener('submit', function(event) {
  if (event.target.id === 'create-task-form') {
    event.preventDefault();
    handleCreateTask(event.target);
  }
});

function handleCreateTask(form) {
  const formData = new FormData(form);
  const agents = Array.from(form.querySelectorAll('input[name="agents"]:checked')).map(cb => cb.value);
  
  const task = {
    id: generateTaskId(),
    title: formData.get('title'),
    description: formData.get('description'),
    priority: formData.get('priority'),
    category: formData.get('category'),
    agents: agents,
    created_at: new Date().toISOString(),
    status: 'todo'
  };
  
  // Add to todo column
  const todoColumn = window.KanbanBoard.columns.find(col => col.id === 'todo');
  if (todoColumn) {
    todoColumn.tasks.push(task);
  }
  
  // Re-render the board
  renderKanbanBoard();
  updateKanbanStats();
  
  // Close modal and reset form
  closeModal('create-task-modal');
  form.reset();
  
  showNotification('Task created successfully', 'success');
}

// Utility functions
function refreshKanban() {
  loadKanbanData();
}

function exportTasks() {
  const allTasks = [];
  window.KanbanBoard.columns.forEach(column => {
    allTasks.push(...column.tasks.map(task => ({
      ...task,
      column: column.title
    })));
  });
  
  const dataStr = JSON.stringify(allTasks, null, 2);
  const dataBlob = new Blob([dataStr], { type: 'application/json' });
  
  const link = document.createElement('a');
  link.href = URL.createObjectURL(dataBlob);
  link.download = 'enhance-swarm-tasks.json';
  link.click();
  
  showNotification('Tasks exported successfully', 'success');
}

function showKanbanError(message) {
  const board = document.getElementById('kanban-board');
  if (board) {
    board.innerHTML = `
      <div class="kanban-error">
        <i class="fas fa-exclamation-triangle"></i>
        <h3>Unable to load tasks</h3>
        <p>${escapeHtml(message)}</p>
        <button class="btn btn-primary" onclick="loadKanbanData()">
          <i class="fas fa-retry"></i> Retry
        </button>
      </div>
    `;
  }
}

function formatTaskDate(dateString) {
  if (!dateString) return 'Unknown';
  
  try {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    
    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;
    
    return date.toLocaleDateString();
  } catch (error) {
    return 'Unknown';
  }
}

function escapeHtml(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Add custom styles for kanban
const kanbanStyles = `
  .task-card-ghost {
    opacity: 0.5;
  }
  
  .task-card-drag {
    transform: rotate(5deg);
  }
  
  .task-agents {
    margin-top: 0.5rem;
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
  }
  
  .task-agent {
    background: var(--primary-color);
    color: white;
    padding: 0.125rem 0.5rem;
    border-radius: 12px;
    font-size: 0.75rem;
  }
  
  .task-agent-more {
    background: var(--text-secondary);
    color: white;
    padding: 0.125rem 0.5rem;
    border-radius: 12px;
    font-size: 0.75rem;
  }
  
  .kanban-error {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 400px;
    text-align: center;
    color: var(--text-secondary);
  }
  
  .kanban-error i {
    font-size: 3rem;
    margin-bottom: 1rem;
    color: var(--warning-color);
  }
  
  .detail-row {
    margin-bottom: 1rem;
  }
  
  .detail-row strong {
    display: block;
    margin-bottom: 0.5rem;
    color: var(--text-primary);
  }
  
  .agent-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }
  
  .agent-tag {
    background: var(--light-bg);
    padding: 0.25rem 0.75rem;
    border-radius: 16px;
    border: 1px solid var(--border-color);
    font-size: 0.875rem;
  }
`;

const kanbanStyleSheet = document.createElement('style');
kanbanStyleSheet.textContent = kanbanStyles;
document.head.appendChild(kanbanStyleSheet);