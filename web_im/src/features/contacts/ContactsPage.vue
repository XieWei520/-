<script setup lang="ts">
import { fakeContacts, fakeGroups } from '../../mocks/fakeImData';
</script>

<template>
  <main class="page">
    <header class="page-header">
      <h1>通讯录</h1>
      <p>联系人和群组来自本地假数据</p>
    </header>

    <section aria-labelledby="contacts-title">
      <h2 id="contacts-title" class="section-title">联系人</h2>
      <ul class="list">
        <li v-for="contact in fakeContacts" :key="contact.id" class="list-row static-row">
          <span class="avatar" aria-hidden="true">{{ contact.avatarText }}</span>
          <span class="row-main">
            <span class="row-title">{{ contact.name }}</span>
            <span class="row-subtitle">{{ contact.title }} - {{ contact.phone }}</span>
          </span>
          <span class="status-dot" :class="{ online: contact.online }" :aria-label="contact.online ? '在线' : '离线'" />
        </li>
      </ul>
    </section>

    <section aria-labelledby="groups-title">
      <h2 id="groups-title" class="section-title">群组</h2>
      <ul class="list">
        <li v-for="group in fakeGroups" :key="group.id" class="list-row static-row">
          <span class="avatar" aria-hidden="true">{{ group.avatarText }}</span>
          <span class="row-main">
            <span class="row-title">{{ group.name }}</span>
            <span class="row-subtitle">{{ group.description }}</span>
          </span>
          <span class="member-count">{{ group.memberCount }} 人</span>
        </li>
      </ul>
    </section>
  </main>
</template>
