<template>
  <div 
    :class="[
      'sakura-ai-assistant',
      isOpen ? 'open' : '',
      isRTL ? 'rtl' : 'ltr'
    ]"
    :style="{ 
      [isRTL ? 'left' : 'right']: '20px',
      [isRTL ? 'right' : 'left']: 'auto',
      bottom: '20px'
    }"
  >
    <!-- Chat Button -->
    <button
      v-if="!isOpen"
      @click="toggleChat"
      class="chat-button"
      :aria-label="$t('ai.chatButton')"
    >
      <i class="fas fa-comments"></i>
    </button>

    <!-- Chat Window -->
    <div v-if="isOpen" class="chat-window">
      <!-- Header -->
      <div class="chat-header">
        <div class="chat-title">
          <i class="fas fa-robot mr-2"></i>
          <span>{{ $t('ai.title') }}</span>
        </div>
        <button @click="toggleChat" class="close-button" :aria-label="$t('common.close')">
          <i class="fas fa-times"></i>
        </button>
      </div>

      <!-- Messages -->
      <div class="chat-messages" ref="messagesContainer">
        <div
          v-for="(message, index) in messages"
          :key="index"
          :class="['message', message.role]"
        >
          <div class="message-content">
            {{ message.content }}
          </div>
          <div class="message-time">
            {{ formatTime(message.timestamp) }}
          </div>
        </div>
        <div v-if="isTyping" class="message assistant typing">
          <div class="message-content">
            <span class="typing-indicator">
              <span></span><span></span><span></span>
            </span>
          </div>
        </div>
      </div>

      <!-- Input -->
      <div class="chat-input">
        <input
          v-model="inputMessage"
          @keyup.enter="sendMessage"
          type="text"
          :placeholder="$t('ai.placeholder')"
          class="message-input"
        />
        <button
          @click="sendMessage"
          :disabled="!inputMessage.trim() || isTyping"
          class="send-button"
          :aria-label="$t('ai.send')"
        >
          <i class="fas fa-paper-plane"></i>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useI18n } from '@/composables/useI18n';
import { useAuthStore } from '@/stores/auth';
import { generateIntelligentResponse } from '@/services/aiChatbotService';

const { locale, t } = useI18n();
const authStore = useAuthStore();

const isOpen = ref(false);
const inputMessage = ref('');
const messages = ref([
  {
    role: 'assistant',
    content: locale.value === 'ar' 
      ? 'مرحباً، أنا مساعدك الذكي في نظام ساكورا ERP. يمكنني مساعدتك في البحث عن بيانات النظام.'
      : 'Hello, I\'m your intelligent assistant in the Sakura ERP system. I can help you find system data.',
    timestamp: new Date()
  }
]);
const isTyping = ref(false);
const messagesContainer = ref(null);

const isRTL = computed(() => locale.value === 'ar');

const toggleChat = () => {
  isOpen.value = !isOpen.value;
};

const formatTime = (date) => {
  return new Intl.DateTimeFormat(isRTL.value ? 'ar-SA' : 'en-US', {
    hour: '2-digit',
    minute: '2-digit'
  }).format(date);
};

const scrollToBottom = async () => {
  await nextTick();
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight;
  }
};

const sendMessage = async () => {
  if (!inputMessage.value.trim() || isTyping.value) return;

  const userMessage = inputMessage.value.trim();
  inputMessage.value = '';

  // Add user message
  messages.value.push({
    role: 'user',
    content: userMessage,
    timestamp: new Date()
  });

  await scrollToBottom();

  // Show typing indicator
  isTyping.value = true;
  await scrollToBottom();

  // Generate intelligent response using real ERP data (STRICT - NO GENERIC RESPONSES)
  try {
    const response = await generateIntelligentResponse(userMessage, locale.value, authStore.user);
    
    // RUNTIME ASSERTION: Block any generic response strings before displaying
    if (typeof response === 'string') {
      const forbiddenStrings = [
        'understand your question',
        'can answer about',
        'please ask',
        'What would you like',
        'How can I help',
        'You can ask',
        'What specifically',
        'What do you want'
      ];
      
      const lowerResponse = response.toLowerCase();
      for (const forbidden of forbiddenStrings) {
        if (lowerResponse.includes(forbidden.toLowerCase())) {
          throw new Error(`FORBIDDEN: Generic chatbot response detected in UI: "${forbidden}". Response: "${response.substring(0, 100)}"`);
        }
      }
    }
    
    messages.value.push({
      role: 'assistant',
      content: response,
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Error generating AI response:', error);
    
    // Professional ERP error message - no generic help text
    const isGenericResponseError = error.message && error.message.includes('FORBIDDEN: Generic chatbot response');
    
    const fallbackResponse = isGenericResponseError
      ? (locale.value === 'ar'
          ? 'خطأ في النظام: تم اكتشاف استجابة عامة محظورة. يرجى التواصل مع فريق الدعم التقني.'
          : 'System error: Forbidden generic response detected. Please contact technical support.')
      : (locale.value === 'ar'
          ? 'عذراً، حدث خطأ أثناء معالجة طلبك. يرجى المحاولة مرة أخرى.'
          : "I apologize, an error occurred while processing your request. Please try again.");
    
    messages.value.push({
      role: 'assistant',
      content: fallbackResponse,
      timestamp: new Date()
    });
  } finally {
    isTyping.value = false;
    scrollToBottom();
  }
};

watch(() => messages.value.length, () => {
  scrollToBottom();
});
</script>

<style scoped>
.sakura-ai-assistant {
  position: fixed;
  z-index: 1000;
  font-family: inherit;
}

.chat-button {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: linear-gradient(135deg, #284b44 0%, #956c2a 100%);
  color: white;
  border: none;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  transition: all 0.3s ease;
}

.chat-button:hover {
  transform: scale(1.1);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.2);
}

.chat-window {
  width: 380px;
  max-width: calc(100vw - 40px);
  height: 600px;
  max-height: calc(100vh - 100px);
  background: white;
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.15);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.chat-header {
  background: linear-gradient(135deg, #284b44 0%, #956c2a 100%);
  color: white;
  padding: 16px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.chat-title {
  font-weight: 600;
  font-size: 16px;
  display: flex;
  align-items: center;
}

.close-button {
  background: none;
  border: none;
  color: white;
  cursor: pointer;
  font-size: 20px;
  padding: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: opacity 0.2s;
}

.close-button:hover {
  opacity: 0.7;
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.message {
  display: flex;
  flex-direction: column;
  max-width: 80%;
}

.message.user {
  align-self: flex-end;
}

.message.assistant {
  align-self: flex-start;
}

.message-content {
  padding: 12px 16px;
  border-radius: 12px;
  word-wrap: break-word;
  line-height: 1.5;
}

.message.user .message-content {
  background: #284b44;
  color: white;
  border-bottom-right-radius: 4px;
}

.message.assistant .message-content {
  background: #f0e1cd;
  color: #333;
  border-bottom-left-radius: 4px;
}

.message-time {
  font-size: 11px;
  color: #999;
  margin-top: 4px;
  padding: 0 4px;
}

.message.user .message-time {
  text-align: right;
}

.message.assistant .message-time {
  text-align: left;
}

.typing-indicator {
  display: flex;
  gap: 4px;
  padding: 8px 0;
}

.typing-indicator span {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #999;
  animation: typing 1.4s infinite;
}

.typing-indicator span:nth-child(2) {
  animation-delay: 0.2s;
}

.typing-indicator span:nth-child(3) {
  animation-delay: 0.4s;
}

@keyframes typing {
  0%, 60%, 100% {
    transform: translateY(0);
    opacity: 0.7;
  }
  30% {
    transform: translateY(-10px);
    opacity: 1;
  }
}

.chat-input {
  padding: 16px;
  border-top: 1px solid #e5e7eb;
  display: flex;
  gap: 8px;
}

.message-input {
  flex: 1;
  padding: 12px 16px;
  border: 1px solid #e5e7eb;
  border-radius: 24px;
  font-size: 14px;
  outline: none;
  transition: border-color 0.2s;
}

.message-input:focus {
  border-color: #284b44;
}

.send-button {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: #284b44;
  color: white;
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background-color 0.2s;
}

.send-button:hover:not(:disabled) {
  background: #1f3d38;
}

.send-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.rtl .message.user .message-time {
  text-align: left;
}

.rtl .message.assistant .message-time {
  text-align: right;
}

@media (max-width: 640px) {
  .chat-window {
    width: calc(100vw - 20px);
    height: calc(100vh - 100px);
    border-radius: 12px;
  }
}
</style>
