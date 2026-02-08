<template>
  <div :class="['skeleton-loader', containerClass]" :style="containerStyle">
    <div 
      v-for="n in lines" 
      :key="n"
      :class="['skeleton-line', lineClass]"
      :style="getLineStyle(n)"
    ></div>
  </div>
</template>

<script setup>
const props = defineProps({
  lines: {
    type: Number,
    default: 3
  },
  containerClass: {
    type: String,
    default: ''
  },
  lineClass: {
    type: String,
    default: ''
  },
  containerStyle: {
    type: Object,
    default: () => ({})
  },
  variant: {
    type: String,
    default: 'default', // 'default', 'card', 'table-row', 'text'
    validator: (value) => ['default', 'card', 'table-row', 'text'].includes(value)
  }
});

const getLineStyle = (index) => {
  const baseStyle = {};
  
  if (props.variant === 'card') {
    baseStyle.height = index === 1 ? '24px' : '16px';
    baseStyle.width = index === 1 ? '60%' : index === props.lines ? '40%' : '80%';
    baseStyle.marginBottom = '12px';
  } else if (props.variant === 'table-row') {
    baseStyle.height = '20px';
    baseStyle.width = index === 1 ? '30%' : index === 2 ? '25%' : '20%';
  } else if (props.variant === 'text') {
    baseStyle.height = '16px';
    baseStyle.width = index === props.lines ? '60%' : '100%';
    baseStyle.marginBottom = '8px';
  } else {
    baseStyle.height = '16px';
    baseStyle.width = index === props.lines ? '70%' : '100%';
    baseStyle.marginBottom = '8px';
  }
  
  return baseStyle;
};
</script>

<style scoped>
.skeleton-loader {
  width: 100%;
}

.skeleton-line {
  background: linear-gradient(
    90deg,
    #f3f4f6 0%,
    #e5e7eb 20%,
    #284b44 40%,
    #e5e7eb 60%,
    #f3f4f6 80%,
    #f3f4f6 100%
  );
  background-size: 1000px 100%;
  animation: sakura-shimmer 2s infinite;
  opacity: 0.7;
  border-radius: 4px;
}

@keyframes sakura-shimmer {
  0% {
    background-position: -1000px 0;
  }
  100% {
    background-position: 1000px 0;
  }
}
</style>
